FROM node:16

WORKDIR /home/app
COPY index.js package.json ./
EXPOSE 3000
RUN npm install
CMD node /home/app/index.js