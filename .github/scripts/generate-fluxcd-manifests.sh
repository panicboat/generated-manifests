#!/bin/bash

set -e

echo "🚀 Generating FluxCD manifests..."

# 環境リスト
ENVIRONMENTS=("develop" "staging" "production")

for env in "${ENVIRONMENTS[@]}"; do
    echo "📦 Processing environment: $env"

    # 環境ディレクトリが存在するかチェック
    if [ ! -d "services/$env" ]; then
        echo "📝 Environment directory services/$env does not exist, creating empty FluxCD structure..."
    fi

    # clusters配下のディレクトリ作成
    mkdir -p "clusters/$env/flux-system"
    mkdir -p "clusters/$env/apps"

    # flux-system用のkustomization.yamlを生成
    cat > "clusters/$env/flux-system/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - gotk-sync.yaml
EOF

    # gotk-sync.yamlを生成
    cat > "clusters/$env/flux-system/gotk-sync.yaml" << EOF
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m0s
  ref:
    branch: main
  url: https://github.com/$(basename $(git config --get remote.origin.url) .git)
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./clusters/$env
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
EOF

    # 各サービスのmanifestを走査してapp用のkustomizationを生成
    echo "📝 Generating app manifests for $env..."

    # apps配下のkustomization.yamlを生成
    cat > "clusters/$env/apps/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
EOF

    # 環境ディレクトリ内のYAMLファイルを探索
    if [ -d "services/$env" ] && ls services/$env/*.yaml 1> /dev/null 2>&1; then
        echo "resources:" >> "clusters/$env/apps/kustomization.yaml"
        for manifest in services/$env/*.yaml; do
            service_name=$(basename "$manifest" .yaml)
            echo "  - $service_name.yaml" >> "clusters/$env/apps/kustomization.yaml"

            # HelmReleaseまたはKustomizationリソースを生成
            cat > "clusters/$env/apps/$service_name.yaml" << EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: $service_name
  namespace: flux-system
spec:
  interval: 5m0s
  path: ./services/$env
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  targetNamespace: default
  postBuild:
    substitute:
      service_name: "$service_name"
EOF
        done
    else
        if [ -d "services/$env" ]; then
            echo "⚠️  No YAML files found in services/$env directory"
        else
            echo "📝 Environment directory services/$env does not exist, creating empty structure"
        fi
        # 空のresourcesの場合
        echo "resources: []" >> "clusters/$env/apps/kustomization.yaml"
    fi

    echo "✅ Generated FluxCD manifests for $env"
done

echo "🎉 FluxCD manifests generation completed!"
