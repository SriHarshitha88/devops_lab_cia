# Use Node.js 18 Alpine as base image
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (tolerate missing package-lock)
RUN npm install --omit=dev

# Copy application code
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# Production stage
FROM node:18-alpine AS production

# Set working directory
WORKDIR /app

# Copy installed dependencies from builder
COPY --from=builder --chown=node:node /app/node_modules ./node_modules

# Copy application code
COPY --from=builder --chown=node:node /app .

# Switch to built-in non-root user provided by the image
USER node

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://localhost:3000/health || exit 1

# Start the application
CMD ["npm", "start"]