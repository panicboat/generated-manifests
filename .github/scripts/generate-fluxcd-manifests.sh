#!/bin/bash

set -e

echo "🚀 Generating FluxCD manifests..."

# 環境リスト
ENVIRONMENTS=("develop" "staging" "production")

for env in "${ENVIRONMENTS[@]}"; do
    echo "📦 Processing environment: $env"

    # 環境ディレクトリが存在するかチェック
    if [ ! -d "$env" ]; then
        echo "📝 Environment directory $env does not exist, creating empty FluxCD structure..."
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

    # 環境ディレクトリが存在するかチェック
    if [ -d "$env" ]; then
        # 環境ディレクトリ内のYAMLファイルを再帰的に探索
        yaml_files=$(find "$env" -name "*.yaml" -type f 2>/dev/null | sort)
        
        if [ -n "$yaml_files" ]; then
            echo "resources:" >> "clusters/$env/apps/kustomization.yaml"
            
            for manifest in $yaml_files; do
                # 相対パスを取得（環境ディレクトリからの相対パス）
                relative_path=${manifest#$env/}
                service_name=$(basename "$manifest" .yaml)
                
                # ディレクトリ構造を保持してclusters配下にディレクトリを作成
                manifest_dir=$(dirname "$relative_path")
                if [ "$manifest_dir" != "." ]; then
                    mkdir -p "clusters/$env/apps/$manifest_dir"
                    echo "  - $relative_path" >> "clusters/$env/apps/kustomization.yaml"
                    
                    # HelmReleaseまたはKustomizationリソースを生成（ディレクトリ構造を維持）
                    cat > "clusters/$env/apps/$relative_path" << EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: $(echo "$relative_path" | sed 's|/|-|g' | sed 's|\.yaml||')
  namespace: flux-system
spec:
  interval: 5m0s
  path: ./$env/$manifest_dir
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  targetNamespace: default
  postBuild:
    substitute:
      service_name: "$service_name"
EOF
                else
                    # 直接配下のファイルの場合
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
  path: ./$env
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  targetNamespace: default
  postBuild:
    substitute:
      service_name: "$service_name"
EOF
                fi
            done
        else
            echo "⚠️  No YAML files found in $env directory"
            echo "resources: []" >> "clusters/$env/apps/kustomization.yaml"
        fi
    else
        echo "📝 Environment directory $env does not exist, creating empty structure"
        echo "resources: []" >> "clusters/$env/apps/kustomization.yaml"
    fi

    echo "✅ Generated FluxCD manifests for $env"
done

echo "🎉 FluxCD manifests generation completed!"
