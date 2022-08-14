# traefik-docker-ark

Assuming you already know how traefik works, we will see through this tutorial how to deploy an Ark server through this reverse proxy.

## Requirements

First of all, install docker through [this tutorial](https://docs.docker.com/engine/install/debian/).

You also need to download docker-compose :

```sh
sudo curl -L "https://github.com/docker/compose/releases/download/v2.9.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
```

Make the file executable :

```sh
sudo chmod +x /usr/local/bin/docker-compose
```

Download this git repository :

```sh
git clone https://github.com/Ph4ntom01/traefik-docker-ark.git ~/traefik-docker-ark
```

## File structure

You must configure the same file structure as below :

```s
    .
    ├── sherlock
    |   ├── resources                       # The bot configuration file
    |   └── sherlock.jar                    # The bot application
    ├── traefik
    |   └── configuration
    |   |   ├── dynamic                     # The fully dynamic routing configuration
    |   |   └── static                      # The startup configuration
    |   └── containers
    |   |   └── ark-server
    |   |       ├── data                    # The Ark installation files
    |   |       └── sherlock.sh             # The Ark management script
    |   └── docker-compose.yml
    ├── LICENSE
    └── README.md
```

## Bot setup

Define Sherlock as a system service, but first of all, make `sherlock.jar` executable :

```sh
sudo chmod +x ~/traefik-docker-ark/sherlock/sherlock.jar
```

### Sherlock service script (sherlock-service.sh)

Create a script in `/usr/local/bin/` that will be able to start and stop the service :

```sh
#!/bin/sh
SERVICE_NAME=sherlock
PATH_TO_JAR=/home/[username]/traefik-docker-ark/sherlock/sherlock.jar
PATH_TO_CONFIG=/home/[username]/traefik-docker-ark/sherlock/resources/sherlock.toml
PID_PATH_NAME=/tmp/sherlock-pid

start() {
    echo "Starting $SERVICE_NAME ..."
    if [ ! -f "$PID_PATH_NAME" ]; then
        sleep 3
        # nohup : keeps the process to remain running after the session is closed.
        # & : runs the command in the background.
        # $! : contains the process ID of the most recently executed background pipeline.
        nohup java -jar "$PATH_TO_JAR" "$PATH_TO_CONFIG" /tmp 2> /dev/null & echo "$!" > "$PID_PATH_NAME"
        echo "$SERVICE_NAME started ..."
    else
        echo "$SERVICE_NAME is already running ..."
    fi
}

stop() {
    if [ -f "$PID_PATH_NAME" ]; then
        PID=$(cat "$PID_PATH_NAME");
        echo "$SERVICE_NAME stoping ..."
        kill "$PID";
        echo "$SERVICE_NAME stopped ..."
        rm "$PID_PATH_NAME"
    else
        echo "$SERVICE_NAME is not running ..."
    fi
}

case "$1" in
    start)
        start
    ;;
    stop)
        stop
    ;;
    restart)
        stop
        start
    ;;
esac
```

**Note :**

- Use the correct `sherlock.jar` path in the `PATH_TO_JAR` above variable.
- Use the correct `sherlock.toml` path in the `PATH_TO_CONFIG` above variable.

Make the script executable :

```sh
sudo chmod +x /usr/local/bin/sherlock-service.sh
```

### Sherlock system service (sherlock.service)

Create a service file in `/etc/systemd/system/` :

```sh
[Unit]
Description=Sherlock (Ark server management discord bot)
After=network-online.target

[Service]
Type=forking
Restart=always
RestartSec=3
SuccessExitStatus=143
ExecStart=/usr/local/bin/sherlock-service.sh start
ExecStop=/usr/local/bin/sherlock-service.sh stop
ExecReload=/usr/local/bin/sherlock-service.sh restart

[Install]
WantedBy=multi-user.target
```

### Configuration file (sherlock.toml)

The bot has some parameters to setup.

Your discord profile ID :

```yml
[owner]
id = "your_discord_id"
```

The location of the `sherlock.sh` script (by default: `traefik/containers/ark-server/sherlock.sh`) :

```yml
[directory]
sherlock_script = "path/to/script"
```

**Note :** the bot token value will be set [below](#token).

### Service activation

```sh
sudo systemctl daemon-reload
sudo systemctl enable proxy
sudo systemctl start proxy
```

## Docker

Once the bot is setup, go to the `traefik` directory :

```sh
cd ~/traefik-docker-ark/traefik
```

Launch the docker-compose file :


```sh
docker-compose up -d
```

Check if the container is running :

```sh
docker ps
```

The `sherlock.sh` script needs **aliases** to work properly :

```sh
alias arkbackup='docker exec ark-server arkmanager backup'
alias arklistplayers='docker exec ark-server arkmanager rconcmd "listPlayers"'
alias arkmgr='docker exec ark-server arkmanager'
alias arksave='docker exec ark-server arkmanager saveworld'
alias arkstart='docker exec ark-server arkmanager start'
alias arkstats='docker exec ark-server arkmanager status'
alias arkstop='docker exec ark-server arkmanager stop'
```

Put these in your ~/.bashrc file.

Reload `.bashrc` settings without logging out and back in again :

```sh
source ~/.bashrc
```

## Discord

### Token

In order to use the bot, you need to create a token through the [Discord Developer Portal](https://discord.com/developers/applications).

This token must be placed in the `sherlock/resources/sherlock.toml` configuration file :

```s
[bot]
token = "your_bot_token"
```

Restart the bot :

```sh
sudo systemctl restart sherlock
```

### Add the bot in a discord server

In the [Discord Developer Portal](https://discord.com/developers/applications), go to `OAuth2` -> `URL Generator` and check the `bot` box. Then, check the desired permissions and an URL must appear.

### Commands

By using the `?help` command, the bot sends a private message containing all the commands.
