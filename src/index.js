const express = require('express')
const app = express()

const TEST_VAR = process.env.TEST_VAR || ':-('
const PORT = process.env.PORT || 3000

app.get('/', (req, res) => {
  console.log('GET /')
  res.json({ message: `[${TEST_VAR}] Howdy, how is going? All good over here :-)` })
})

app.listen(PORT, () => {
  console.log(`Example api is listening on ${PORT}`)
})