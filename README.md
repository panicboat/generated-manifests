### Require

- [k3d](https://github.com/panicboat/platform/tree/main/kubernetes) での構築前提です。
- gitea 以外の環境では [gotk-sync.yaml](clusters/k3d/flux-system/gotk-sync.yaml) の修正が必要になります。

### Usage

gitea に generated-manifests リポジトリを作成し、以下のコマンドを実行します。

```console
git remote add gitea http://giteaadmin:admin123@localhost:3000/giteaadmin/generated-manifests.git
git push -u gitea main
kubectl apply -k clusters/k3d
```

`flux get kustomizations` コマンドで以下のようになったら成功です。

```console
NAME                    REVISION                SUSPENDED       READY   MESSAGE
cilium                  main@sha1:a8b38fe2      False           True    Applied revision: main@sha1:a8b38fe2
gateway-api             main@sha1:a8b38fe2      False           True    Applied revision: main@sha1:a8b38fe2
generated-manifests     main@sha1:3b7a8810      False           True    Applied revision: main@sha1:3b7a8810  # <-- 今回追加されるリソース
gitea                   main@sha1:a8b38fe2      False           True    Applied revision: main@sha1:a8b38fe2
helmrepositories        main@sha1:a8b38fe2      False           True    Applied revision: main@sha1:a8b38fe2
kubernetes              main@sha1:a8b38fe2      False           True    Applied revision: main@sha1:a8b38fe2
opentelemetry           main@sha1:a8b38fe2      False           True    Applied revision: main@sha1:a8b38fe2
prometheus-operator     main@sha1:a8b38fe2      False           True    Applied revision: main@sha1:a8b38fe2
services-nginx-app      main@sha1:3b7a8810      False           True    Applied revision: main@sha1:3b7a8810
```

#### Cleanup

```console
git remote remove gitea
```
