# generated-manifests

### Develop

```sh
export GITHUB_USER=panicboat
export GITHUB_TOKEN=ghp_XXXXXXXXX
```

```sh
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=generated-manifests \
  --branch=main \
  --path=./clusters/develop \
  --personal
```

#### /etc/hosts
```sh
# Ingress
127.0.0.1 nginx.local
```
