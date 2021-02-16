#!/bin/bash

export http_proxy="http://${internet_proxy}:3128"
export HTTP_PROXY="$http_proxy"
export https_proxy="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export no_proxy="${non_proxied_endpoints}"
export NO_PROXY="$no_proxy"

