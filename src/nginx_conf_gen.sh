#!/bin/bash

export LC_ALL=en_US.utf-8
export LANG=en_US.utf-8
export IMAGE_TAG=$(git rev-parse --short=7 HEAD)
export GIT_COMMIT=$(git rev-parse HEAD)

APP_NAME=`node -e 'console.log(require("./package.json").insights.appname)'`
NPM_INFO="undefined"
PATTERNFLY_DEPS="undefined"

function generate_nginx_conf() {
  PREFIX=""
  if [[ "${TRAVIS_BRANCH}" = "master" ||  "${TRAVIS_BRANCH}" = "main" || "${TRAVIS_BRANCH}" =~ "beta" ]]; then
    PREFIX="/beta"
  fi

  echo "server {
   listen 8000;
   server_name $APP_NAME;

   location / {
    try_files \$uri \$uri/ $PREFIX/apps/chrome/index.html;
   }

   location $PREFIX/apps/$APP_NAME {
     alias /opt/app-root/src;
   }
  }
  " > $APP_ROOT/nginx.conf
}

function generate_dockerfile() {
  cat << EOF > $APP_ROOT/Dockerfile
FROM registry.access.redhat.com/ubi8/nginx-118

COPY ./nginx.conf /opt/app-root/etc/nginx/conf.d/default.conf
COPY . /opt/app-root/src
ADD ./nginx.conf "${NGINX_CONFIGURATION_PATH}"

CMD ["nginx", "-g", "daemon off;"]
EOF
}

if [[ -f package-lock.json ]] || [[ -f yarn.lock ]];
then
  LINES=`npm list --silent --depth=0 --production | grep @patternfly -i | sed -E "s/^(.{0})(.{4})/\1/" | tr "\n" "," | sed -E "s/,/\",\"/g"`
  PATTERNFLY_DEPS="[\"${LINES%???}\"]"
else PATTERNFLY_DEPS="[]"
fi

if [[ -n "$APP_BUILD_DIR" &&  -d $APP_BUILD_DIR ]]
then
    cd $APP_BUILD_DIR
else
    cd dist || cd build
fi

echo $NPM_INFO > ./app.info.deps.json

echo "{
  \"app_name\": \"$APP_NAME\",
  \"src_hash\": \"$GIT_COMMIT\",
  \"patternfly_dependencies\": $PATTERNFLY_DEPS,
}" > $APP_ROOT/app.info.json

if [[ -f $APP_ROOT/nginx.conf ]]; then
  echo "nginx config already exists, skipping generation"
else
  generate_nginx_conf
fi

if [[ -f $APP_ROOT/Dockerfile ]]; then
  echo "Dockerfile already exists, skipping generation"
else
  generate_dockerfile
fi

