# uServer-Logger

A lightweight [ELK stack](https://www.elastic.co/what-is/elk-stack) using [Grafana](https://grafana.com/)
(instead of `Kibana`), [Loki](https://grafana.com/oss/loki/) (instead of `ElasticSearch`),
[Promtail](https://grafana.com/docs/loki/latest/clients/promtail/) (instead of `Logstash`), and a custom container to
monitor the docker environment (acting as a `beat`).

The custom container will create a separated log file for each of the running containers (except for the ones that
belongs to the `userver-logger` stack), in a shared volume that is listened by the `userver-promtail` service that
feeds the `userver-loki` lake.

The logs can be accessed using the `userver-grafana` service, which is exposed in port `3000`, and through the domain
URL if a `VIRTUAL_HOST` environment variable is provided.

This stack is part of the [uServer](https://github.com/ferdn4ndo/userver) project, although you can use it separately
and according to your own needs.

## Features

Some of the features include:

* Automatic log registration of the STDOUT of all the running containers, which is sent to `loki`;
* Container-based logs rotation based on the total line count (configurable using the `MAX_LOG_LINES` env);
* Integration with one nginx container to fetch the access and error logs;
* Watching of the running containers list, logging when a container is started or stopped;

## Prepare the environment

Copy the environment templates:

```
cp container_monitor/.env.template container_monitor/.env
cp grafana/.env.template grafana/.env
cp loki/.env.template loki/.env
cp promtail/.env.template promtail/.env
```

Then edit them accordingly.

## Run the Application

After you've setup your environment variables, simply run:

```sh
docker-compose up --build
```

## License

This application is distributed under the [MIT](https://github.com/ferdn4ndo/userver-logger/blob/main/LICENSE) license.

## Contributors

[ferdn4ndo](https://github.com/ferdn4ndo)

Any help is appreciated! Feel free to review / open an issue / fork / make a PR.
