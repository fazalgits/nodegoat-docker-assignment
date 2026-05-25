FROM node:12-alpine AS dependencies

WORKDIR /app
ENV NODE_ENV=production

COPY package.json package-lock.json ./
RUN npm ci --only=production --ignore-scripts && npm cache clean --force

FROM node:12-alpine AS runtime

WORKDIR /app
ENV NODE_ENV=production
ENV PORT=4000
ENV MONGO_URL=mongodb://mongodb:27017/nodegoat

COPY --from=dependencies --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node . .

USER node

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 CMD node -e "const http=require('http');const port=process.env.PORT||4000;const req=http.get({host:'127.0.0.1',port,path:'/'},res=>process.exit(res.statusCode<500?0:1));req.on('error',()=>process.exit(1));req.setTimeout(4000,()=>{req.destroy();process.exit(1);});"

CMD ["node", "server.js"]
