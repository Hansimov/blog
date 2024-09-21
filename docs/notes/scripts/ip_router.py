import netifaces
import random
import requests
import requests.packages.urllib3.util.connection as urllib3_cn
import socket
import time

from pathlib import Path
from requests.adapters import HTTPAdapter
from tclogger import logger, logstr, decolored, shell_cmd
from typing import Union

REQUESTS_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
}


class IPv6Adapter(HTTPAdapter):
    def __init__(self, source_address, *args, **kwargs):
        self.source_address = source_address
        super().__init__(*args, **kwargs)

    def init_poolmanager(self, *args, **kwargs):
        kwargs["source_address"] = self.source_address
        return super().init_poolmanager(*args, **kwargs)


class RequestsSessionIPv6Adapter:
    @staticmethod
    def force_ipv4():
        urllib3_cn.allowed_gai_family = lambda: socket.AF_INET

    @staticmethod
    def force_ipv6():
        if urllib3_cn.HAS_IPV6:
            urllib3_cn.allowed_gai_family = lambda: socket.AF_INET6

    def adapt(self, session: requests.Session, ip: str):
        try:
            socket.inet_pton(socket.AF_INET6, ip)
        except Exception as e:
            raise ValueError(f"× Invalid IPv6 format: [{ip}]")

        adapter = IPv6Adapter((ip, 0))
        session.mount("http://", adapter)
        session.mount("https://", adapter)

        return session


class IPv6Generator:
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.interfaces = []
        # self.get_prefix()

    def get_addr_prefix(self, addr: str, netmask: str):
        prefix_length = netmask.count("f")
        prefix = addr[: prefix_length // 4 * 5 - 1]
        return prefix, prefix_length * 4

    def get_network_interfaces(self):
        interfaces = netifaces.interfaces()
        for interface in interfaces:
            addresses = netifaces.ifaddresses(interface)
            if netifaces.AF_INET6 not in addresses:
                continue
            for addr_info in addresses[netifaces.AF_INET6]:
                if not addr_info["addr"].startswith("2"):
                    break
                addr = addr_info["addr"]
                netmask = addr_info["netmask"]
                prefix, prefix_bits = self.get_addr_prefix(addr, netmask)
                self.interfaces.append(
                    {
                        "interface": interface,
                        "addr": addr,
                        "netmask": netmask,
                        "prefix": prefix,
                        "prefix_bits": prefix_bits,
                    }
                )

    def get_prefix(self, return_netint: bool = False):
        logger.note("> Get ipv6 prefix:")
        self.get_network_interfaces()
        interface = self.interfaces[0]
        prefix = interface["prefix"]
        prefix_bits = interface["prefix_bits"]
        netint = interface["interface"]
        if self.verbose:
            logger.note(f"> IPv6 prefix:", end=" ")
            logger.success(f"[{prefix}]", end=" ")
            logger.mesg(f"(/{prefix_bits})")
        self.netint = netint
        self.prefix = prefix
        self.prefix_bits = prefix_bits
        logger.file(f"  * prefix: {logstr.success(prefix)}")
        logger.file(f"  * netint: {logstr.success(netint)}")
        if return_netint:
            return self.prefix, netint
        else:
            return self.prefix

    def generate(
        self, prefix: str = None, return_segs: bool = False
    ) -> Union[str, tuple[str, list[str], list[str]]]:
        prefix = prefix or self.prefix
        prefix_segs = prefix.split(":")
        suffix_seg_count = 8 - len(prefix_segs)
        suffix_segs = [f"{random.randint(0, 65535):x}" for _ in range(suffix_seg_count)]
        addr = ":".join(prefix_segs + suffix_segs)
        if return_segs:
            return addr, prefix_segs, suffix_segs
        else:
            return addr


class IPv6RouteModifier:
    def __init__(self, prefix: str, netint: str, ndppd_conf: Union[Path, str] = None):
        self.ndppd_conf = ndppd_conf or Path("/etc/ndppd.conf")
        self.prefix = prefix
        self.netint = netint

    def add_route(self):
        logger.note("> Add IP route:")
        cmd = f"sudo ip route add local {self.prefix}::/64 dev {self.netint}"
        # logger.mesg(cmd)
        shell_cmd(cmd)

    def del_route(self):
        logger.note("> Delete IP route:")
        cmd = f"sudo ip route del local {self.prefix}::/64 dev {self.netint}"
        # logger.mesg(cmd)
        shell_cmd(cmd)

    def modify_ndppd_conf(self, overwrite: bool = False):
        if self.ndppd_conf.exists():
            with open(self.ndppd_conf, "r") as rf:
                old_ndppd_conf_str = rf.read()
            logger.note(f"> Read: {logstr.file(self.ndppd_conf)}")
            logger.mesg(f"{old_ndppd_conf_str}")

        if not self.ndppd_conf.exists() or overwrite:
            new_ndppd_conf_str = (
                f"route-ttl 30000\n"
                f"proxy {logstr.success(self.netint)} {{\n"
                f"    router no\n"
                f"    timeout 500\n"
                f"    ttl 30000\n"
                f"    rule {logstr.success(self.prefix)}::/64 {{\n"
                f"        static\n"
                f"    }}\n"
                f"}}\n"
            )
            logger.note(f"> Write: {logstr.file(self.ndppd_conf)}")
            logger.mesg(f"{new_ndppd_conf_str}")
            with open(self.ndppd_conf, "w") as wf:
                wf.write(decolored(new_ndppd_conf_str))
            logger.success(f"✓ Modified: {logstr.file(self.ndppd_conf)}")

    def restart_ndppd(self):
        logger.note("> Restart ndppd:")
        cmd = "sudo systemctl restart ndppd"
        # logger.mesg(cmd)
        shell_cmd(cmd)
        logger.success(f"✓ Restarted: {logstr.file('ndppd')}")


if __name__ == "__main__":
    generator = IPv6Generator()
    prefix, netint = generator.get_prefix(return_netint=True)

    modifier = IPv6RouteModifier(prefix=prefix, netint=netint)
    modifier.add_route()
    modifier.modify_ndppd_conf(overwrite=True)
    modifier.restart_ndppd()

    sleep_seconds = 5
    logger.note(f"> Waiting {sleep_seconds} seconds for ndppd to work ...")
    time.sleep(sleep_seconds)

    logger.note("> Testing ipv6 addrs:")
    session = requests.Session()
    adapter = RequestsSessionIPv6Adapter()
    for i in range(5):
        ipv6, prefix_segs, suffix_segs = generator.generate(return_segs=True)
        prefix = ":".join(prefix_segs)
        suffix = ":".join(suffix_segs)
        logger.note(f"  > [{prefix}:{logstr.file(suffix)}]")
        adapter.adapt(session, ipv6)
        response = session.get("https://test.ipw.cn", headers=REQUESTS_HEADERS)
        logger.mesg(f"  * [{response.text}]")
