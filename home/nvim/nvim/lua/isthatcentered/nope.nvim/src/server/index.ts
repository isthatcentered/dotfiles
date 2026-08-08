import http from 'node:http'

const server = http.createServer()

server.on('request', (request, response) => {
  console.log(request.url, request.headers,)
  
})

server.on("listening", () => {
  console.log("Server is listening on port 3000")
})

server.on("error", (error) => {
  console.error("server error:::", error)
})

server.on("close", () => {
  console.log("Server is closed")
})

server.listen(3000)
