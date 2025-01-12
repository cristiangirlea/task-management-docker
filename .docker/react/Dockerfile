# Base image for building the app
FROM node:22 AS builder

# Set working directory inside the container
WORKDIR /usr/src/app

# Copy package.json and install dependencies
COPY package*.json ./
RUN npm install

# Copy the entire app
COPY . .

# Build the Next.js app
RUN npm run build

# Base image for serving the app
FROM node:22

# Copy the built app from the builder
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app ./

# Expose port 3000 for Next.js
EXPOSE 3000

# Start the app
CMD ["npm", "run", "start"]
