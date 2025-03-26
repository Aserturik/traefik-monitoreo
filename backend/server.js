const express = require("express");
const app = express();
const port = 3000;

app.get("/", (req, res) => {
  res.send("Hola desde un condetedor docker con Node.js ");
});

app.listen(port, () => {
  console.log(`Servidor ejecutándose en http://localhost:${port}`);
});

function getLocalIPAndTime() {
  const os = require("os");

  let ip = "No disponible";
  const interfaces = os.networkInterfaces();
  for (const iface in interfaces) {
    for (const details of interfaces[iface]) {
      if (details.family === "IPv4" && !details.internal) {
        ip = details.address;
      }
    }
  }

  const now = new Date().toLocaleString(); // Hora local

  return { ip, time: now };
}

app.get("/time", (req, res) => {
  res.send(getLocalIPAndTime());
});
