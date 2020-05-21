import os
import sys
import json
import time
import logging
from urllib.request import Request, urlopen

from boto3.session import Session


class APIClient:

    _DEFAULT_ENDPOINT = "https://aws-access.crute.us/api/account"
    _DEFAULT_ACCOUNT = "alpine-amis-user"

    def __init__(self, entrypoint=None, key=None, account=None):
        self.entrypoint = entrypoint or self._DEFAULT_ENDPOINT
        self.account = account or self._DEFAULT_ACCOUNT
        self.key = key
        self._logger = logging.getLogger(__class__.__name__)

        if not self.key:
            self.key = os.environ.get("IDENTITY_BROKER_API_KEY")

        if not self.key:
            raise Exception("No identity broker key found")

    def _get(self, path):
        while True: # to handle rate limits
            res = urlopen(Request(path, headers={"X-API-Key": self.key}))

            if res.status == 429:
                self._logger.warning(
                    "Rate-limited by identity broker, sleeping 30 seconds")
                time.sleep(30)
                continue

            if res.status not in { 200, 429 }:
                raise Exception(res.reason)

            return json.load(res)

    def get_credentials_url(self):
        for account in self._get(self.entrypoint):
            if account["short_name"] == self.account:
                return account["credentials_url"]

        raise Exception("No account found")

    def get_regions(self):
        out = {}

        for region in self._get(self.get_credentials_url()):
            if region["enabled"]:
                out[region["name"]] = region["credentials_url"]

        return out

    def get_credentials(self, region):
        return self._get(self.get_regions()[region])

    def _boto3_session_from_creds(self, creds, region):
        return Session(
            aws_access_key_id=creds["access_key"],
            aws_secret_access_key=creds["secret_key"],
            aws_session_token=creds["session_token"],
            region_name=region)

    def boto3_session_for_region(self, region):
        return self._boto3_session_from_creds(
            self.get_credentials(region), region)

    def iter_regions(self):
        for region, cred_url in self.get_regions().items():
            yield self._boto3_session_from_creds(self._get(cred_url), region)



#c = APIClient("http://localhost:8080/api/account")
