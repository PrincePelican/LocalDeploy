FROM golang:1.22-alpine AS build

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /hello-service .

FROM alpine:3.20

RUN adduser -D -H appuser
COPY --from=build /hello-service /hello-service
USER appuser
EXPOSE 8040

ENTRYPOINT ["/hello-service"]
