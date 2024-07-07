const express = require("express");
const app = express();
const mongoose = require("mongoose");
const dotenv = require("dotenv");
const pinRoute = require("./routes/pins");
const path = require('path');
const cors = require('cors');

 // Use this after the variable declaration


app.use(cors());
dotenv.config();


app.use(express.json());

mongoose 
 .connect('mongodb+srv://anuragkumarthakur:anurag29@cluster0.oo3kmna.mongodb.net/SIHMap?retryWrites=true&w=majority', {
        useNewUrlParser: true,
        useUnifiedTopology: true,
        useCreateIndex: true,   })   
 .then(() => console.log("MongoDB connected!"))
 .catch(err => console.log(err));

app.use("/api/pins", pinRoute);

app.listen(8800, () => {
  console.log("Backend server is running!");
});

app.use(express.static(path.join(__dirname,"./client/build")));
app.get("*",function(_,res){
  res.sendFile(
    path.join(__dirname,"./client/build/index.html"),
    function(err){
      res.status(500).send(err);
        }
        );
});