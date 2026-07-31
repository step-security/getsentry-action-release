# The multi stage set up *saves* up image size by avoiding the dev dependencies
# required to produce dist/
FROM node:25-alpine@sha256:bdf2cca6fe3dabd014ea60163eca3f0f7015fbd5c7ee1b0e9ccb4ced6eb02ef4 AS builder
WORKDIR /app
# This layer will invalidate upon new dependencies
COPY package.json yarn.lock ./
RUN export YARN_CACHE_FOLDER="$(mktemp -d)" \
  && yarn install --frozen-lockfile --quiet \
  && rm -r "$YARN_CACHE_FOLDER"
# If there's some code changes that causes this layer to
# invalidate but it shouldn't, use .dockerignore to exclude it
COPY . .
RUN yarn build

FROM node:25-alpine@sha256:bdf2cca6fe3dabd014ea60163eca3f0f7015fbd5c7ee1b0e9ccb4ced6eb02ef4 AS app
COPY package.json yarn.lock /getsentry-action-release/
# On the builder image, we install both types of dependencies rather than
# just the production ones. This generates /getsentry-action-release/node_modules
RUN export YARN_CACHE_FOLDER="$(mktemp -d)" \
  && cd /getsentry-action-release \
  && yarn install --frozen-lockfile --production --quiet \
  && rm -r "$YARN_CACHE_FOLDER"

# Copy the artifacts from `yarn build`
COPY --from=builder /app/dist /getsentry-action-release/dist/
RUN chmod +x /getsentry-action-release/dist/index.js

RUN printf '[safe]\n    directory = *\n' > /etc/gitconfig

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
