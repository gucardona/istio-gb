FROM golang:1.22 AS b
WORKDIR /s
COPY go.mod main.go ./
RUN CGO_ENABLED=0 go build -o /svc .
FROM gcr.io/distroless/static
COPY --from=b /svc /svc
ENTRYPOINT ["/svc"]
