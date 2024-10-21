FROM rclone/rclone:1.68.1 AS provider

# To address the issue of dependencies in Alpine's edge version being required while rclone is not yet updated.
# https://github.com/rclone/rclone/blob/master/Dockerfile
FROM postgres:17-alpine AS base

RUN apk --no-cache add ca-certificates fuse3 tzdata && \
  echo "user_allow_other" >> /etc/fuse.conf

COPY --from=provider /usr/local/bin/rclone /usr/local/bin/

RUN find /usr/local/bin -type f -name 'pg_*' ! -name 'pg_dump' ! -name 'pg_restore' -exec rm -f {} +

RUN ls -l /usr/local/bin/pg_*

RUN addgroup -g 1009 rclone && adduser -u 1009 -Ds /bin/sh -G rclone rclone

ENTRYPOINT [ "rclone" ]

WORKDIR /data
ENV XDG_CONFIG_HOME=/config

FROM base

LABEL "repository"="https://github.com/bhunter234/rclone-backup" \
  "homepage"="https://github.com/bhunter234/rclone-backup"

ARG USER_NAME="backuptool"
ARG USER_ID="1100"

ENV LOCALTIME_FILE="/tmp/localtime"

COPY scripts/*.sh /app/

RUN chmod +x /app/*.sh \
  && mkdir -m 777 /data/backup \
  && apk add --no-cache 7zip bash mariadb-client sqlite supercronic s-nail tzdata \
  && apk info --no-cache -Lq mariadb-client | grep -vE '/bin/mariadb$' | grep -vE '/bin/mariadb-dump$' | xargs -I {} rm -f "/{}" \
  && ln -sf "${LOCALTIME_FILE}" /etc/localtime \
  && addgroup -g "${USER_ID}" "${USER_NAME}" \
  && adduser -u "${USER_ID}" -Ds /bin/sh -G "${USER_NAME}" "${USER_NAME}"

ENTRYPOINT ["/app/entrypoint.sh"]
