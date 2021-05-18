const express = require('express')
const server = express()
const port = 8881

server.use(express.json());

server.post('/payments', (req, res) => {
  console.log(req.body);
  res.status(200).send(req.body)
})
 
server.listen(port, () => {
  console.log(`Server is listening on http://localhost:${port}`)
})