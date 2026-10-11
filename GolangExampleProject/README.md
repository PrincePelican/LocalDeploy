# Hello service

Minimalny backend napisany w Go z użyciem Gin.

## Uruchomienie lokalne

```bash
go run .
```

Serwis działa domyślnie na `http://localhost:8040`. Port można zmienić zmienną `PORT`.

```bash
curl http://localhost:8040/hello
# Hello
```

## Testy

```bash
go test ./...
```

## Docker

```bash
docker build -t hello-service .
docker run --rm -p 8040:8040 hello-service
```

## Wdrożenie na lokalny klaster k3d

Pipeline uruchamia job `deploy-develop` po wypchnięciu zmian na gałąź `develop`.
Buduje obraz z aktualnego commita, importuje go do klastra `localdeploy` i
aktualizuje aplikację w namespace `dev`. Namespace `live` jest tworzony pusty.
Nazwa wdrożenia i port aplikacji są ustawione w sekcji `variables` pliku
`.gitlab-ci.yml` (`K3D_APP_NAME` i `K3D_APP_PORT`). Każdy projekt korzystający
ze wspólnego pipeline'u powinien zdefiniować własne, unikalne wartości.
Wspólny release można włączyć przez `RELEASE_ENABLED: "true"` w tym samym
pliku. Zmienna CI/CD `RELEASE_TOKEN` musi być ustawiona w ustawieniach projektu
GitLaba dla aplikacji. Ręczny job na `develop` utworzy Merge Request do `main`;
po jego scaleniu pipeline gałęzi `main` utworzy tag `release.1.0.N`.

Job wymaga runnera z tagiem `local-k3d`, działającego na hoście klastra i
mającego dostęp do `docker`, `k3d`, `kubectl` oraz kontekstu `k3d-localdeploy`.
Po wdrożeniu aplikację można sprawdzić przez przekierowanie portu:

```bash
kubectl --context k3d-localdeploy -n dev port-forward svc/hello-service 18040:8040
curl http://localhost:18040/hello
```
