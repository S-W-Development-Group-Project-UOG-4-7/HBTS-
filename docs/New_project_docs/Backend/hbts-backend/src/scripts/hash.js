import bcrypt from "bcrypt";

const password = process.argv[2];

if (!password) {
  console.log("Usage: node src/scripts/hash.js <password>");
  process.exit(1);
}

const hash = await bcrypt.hash(password, 10);
console.log(hash);
