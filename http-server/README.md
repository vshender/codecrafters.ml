# [Build your own HTTP server](https://app.codecrafters.io/courses/http-server/introduction)

## Introduction

Welcome to the Build your own HTTP server challenge!

HTTP is the protocol that powers the web.  In this challenge, you'll build a HTTP server that's capable of handling simple GET/POST requests, serving files and handling multiple concurrent connections.

Along the way, we'll learn about TCP connections, HTTP headers, HTTP verbs, handling multiple connections and more.


## Bind to a port

In this stage, you'll create a TCP server that listens on port 4221.

[TCP](https://www.cloudflare.com/en-ca/learning/ddos/glossary/tcp-ip/) is the underlying protocol used by HTTP servers.

### Tests

The tester will execute your program like this:
```
$ dune exec ./http_server.exe
```

Then, the tester will try to connect to your server on port 4221.  The connection must succeed for you to pass this stage.
