# Web build of the Flutter app, served by nginx.
# nginx also proxies /api to the gateway, so the app calls its own origin.
FROM ghcr.io/cirruslabs/flutter:3.41.9 AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# Empty = call the origin the page was loaded from (see lib/services/api_config.dart)
ARG API_BASE_URL=
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:1.29-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
