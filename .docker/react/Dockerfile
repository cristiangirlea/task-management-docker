FROM node:22

WORKDIR /usr/src/app

# Copy package.json and install dependencies
COPY package*.json ./

RUN npm install

# Copy the rest of the app
COPY . ./

# Expose the development port (3000 by default)
EXPOSE 3000

# Run the frontend in development mode
CMD ["npm", "run", "dev"]
