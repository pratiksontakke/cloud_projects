// Load environment variables if using a .env file (optional, but good practice)
// You might need to install dotenv: npm install dotenv
// require('dotenv').config(); // Uncomment if you want to use a .env file for local dev

module.exports = {
  // Read values from environment variables
  HOST: process.env.DB_HOST || "localhost", // Default for local dev if needed
  USER: process.env.DB_USER || "postgres", // Default for local dev if needed
  PASSWORD: process.env.DB_PASSWORD || "postgres_123", // Default for local dev if needed
  DB: process.env.DB_NAME || "postgres", // Default for local dev if needed
  dialect: "postgres",
  dialectOptions: {
    // SSL should ideally be configurable too, but start simple
    ssl: {
      // In AWS RDS, often require: true is needed. Set via env var?
      require: process.env.DB_SSL_REQUIRE === 'true' || true, // Default to true for RDS
      rejectUnauthorized: process.env.DB_SSL_REJECT_UNAUTHORIZED === 'true' || false // RDS often needs false unless using custom CA
    }
  },
  pool: {
    max: parseInt(process.env.DB_POOL_MAX || "5"), // Allow configuring pool via env vars
    min: parseInt(process.env.DB_POOL_MIN || "0"),
    acquire: parseInt(process.env.DB_POOL_ACQUIRE || "30000"),
    idle: parseInt(process.env.DB_POOL_IDLE || "10000")
  }
};