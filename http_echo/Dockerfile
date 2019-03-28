FROM golang:1.12.1-alpine

WORKDIR /go/src/app
COPY . .

RUN apk --no-cache add git
RUN go get -d -v ./...
RUN go install -v ./...

CMD ["app"]
