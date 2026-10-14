FROM node:22-bookworm-slim
WORKDIR /app
COPY package.json ./
COPY server ./server
COPY oyun ./oyun
COPY kart-prototipi ./kart-prototipi
COPY index.html online.html manifest.webmanifest sw.js ./
ENV HOST=0.0.0.0 PORT=8080 DESTAN_DATA_DIR=/app/.data
EXPOSE 8080
CMD ["node", "server/http.js"]
