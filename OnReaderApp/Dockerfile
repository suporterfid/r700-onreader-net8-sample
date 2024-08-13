#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.
# run the build:
# docker build --platform=linux/arm -t smartreader -f ./Dockerfile ../
# docker build --progress=plain --platform=linux/arm -t smartreader-upgx -f ./Dockerfile ../
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
USER app
WORKDIR /app
EXPOSE 8443

ARG BUILDPLATFORM=linux/arm

FROM --platform=$BUILDPLATFORM  mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG BUILD_CONFIGURATION=Release
ARG TARGETARCH=arm
WORKDIR /src
COPY *.sln .
COPY ["OnReaderApp/OnReaderApp.csproj", "OnReaderApp/"]
RUN dotnet restore OnReaderApp/OnReaderApp.csproj
COPY . .
WORKDIR "/src/."
RUN dotnet build "./OnReaderApp/OnReaderApp.csproj" -c $BUILD_CONFIGURATION -o /app/build --arch $TARGETARCH

RUN dotnet publish "./OnReaderApp/OnReaderApp.csproj" -o /app -c $BUILD_CONFIGURATION /p:UseAppHost=true --runtime linux-arm --self-contained
RUN ls -l /app
RUN dotnet publish "./OnReaderApp/OnReaderApp.csproj" -o /app64 /p:UseAppHost=true --runtime win-x64 --self-contained
RUN ls -l /app64

ENTRYPOINT ["dotnet", "OnReaderApp.dll"]

FROM --platform=linux/x86_64 ubuntu:20.04 as myupgx
RUN apt-get update --fix-missing && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install \
    build-essential \
    cmake \
    file \
    squashfs-tools \
    dos2unix \
    zip \
    unzip \
    locales && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

WORKDIR /etk
RUN chmod 777 /etk
#COPY etk_tools/8.1.0_Octane_Embedded_Development_Tools.tar.gz /tmp/
COPY --from=build /src/OnReaderApp/etk_tools/8.1.0_Octane_Embedded_Development_Tools.tar.gz /tmp/
RUN tar -xvzf /tmp/8.1.0_Octane_Embedded_Development_Tools.tar.gz -C /tmp/
RUN rm -rf /tmp/8.1.0_Octane_Embedded_Development_Tools.tar.gz
COPY --from=build /app /etk/cap
COPY --from=build /app/cap_template/* /etk/cap
RUN rm -rf /etk/cap/OnReaderApp.deps.json
COPY --from=build /app/OnReaderApp.deps.json /etk/cap
RUN ls -l /etk
RUN ls -l /etk/cap
RUN ls -l /etk/cap/build
RUN rm -rf /etk/cap/build
RUN mv /etk/cap/cap_gen.sh /tmp/8.1.0_Octane_Embedded_Development_Tools/
RUN mv /etk/cap/cap_description.in /etk/cap_description.in
RUN mv /etk/cap/capcommand.sh /etk/capcommand.sh
RUN mv /etk/cap/cap_template/sys /etk/cap/sys


RUN chmod 755 /etk/cap/start
RUN chmod 755 /etk/cap/OnReaderApp*
RUN chmod 755 /etk/cap/*.so
RUN chmod 755 /etk/cap/*.dll
RUN chmod 755 /etk/cap/*.json
RUN dos2unix /etk/*.in
RUN dos2unix /etk/cap/cust_app_upgrade
RUN chmod -R 775 /etk/cap/*
RUN rm -rf /etk/cap/cap_template
RUN /tmp/8.1.0_Octane_Embedded_Development_Tools/cap_gen.sh -d /etk/cap_description.in -o /etk/onreaderapp_cap.upgx
RUN chmod 777 /etk/onreaderapp_cap.upgx
RUN cp /etk/onreaderapp_cap.upgx /tmp/


