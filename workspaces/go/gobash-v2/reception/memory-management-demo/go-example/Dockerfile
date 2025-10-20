FROM golang:1.23

WORKDIR /app

COPY go.mod .
COPY main.go .

RUN go build -o main main.go
