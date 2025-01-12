# Base image with Node.js 22
FROM node:22

# Set working directory inside the container
WORKDIR /usr/src/app

# Copy only package.json and package-lock.json (for caching)
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy the rest of the app
COPY . .

# Expose port 4000 for Express.js
EXPOSE 4000

# Start the app
CMD ["npm", "start"]
