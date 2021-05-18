const express = require('express')
const crypto = require('crypto')

const server = express()
const port = 8885

server.use(express.json());

var algorithm = 'aes256';
var key = 'example_encryption_key_123456789';
var iv = "example_iv_12345"

// Serve a POST /tokenize API call 
server.post('/tokenize', (req, res) => {

  // req.body should be validated first here.

  data = JSON.stringify(req.body)

  // encrypt the card data atrributes to create a token
  var cipher = crypto.createCipheriv(algorithm, key, iv);  
  var token = cipher.update(data, 'utf8', 'hex') + cipher.final('hex');

  json = {
  	"token": token
  };

  res.status(200).send(JSON.stringify(json))
})

// Serve a POST /detokenize API call
server.post('/detokenize', (req, res) => {
  var token = req.body.token;

  // decrypt a token and return the original payload
  var decipher = crypto.createDecipheriv(algorithm, key, iv);
  var decrypted = decipher.update(token, 'hex', 'utf8') + decipher.final('utf8');

  res.status(200).send(decrypted)
})

server.listen(port, () => {
  console.log(`Server is listening on http://localhost:${port}`)
})