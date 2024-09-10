import netifaces
import random
import requests
import requests.packages.urllib3.util.connection as urllib3_cn
import socket

from tclogger import logger
from requests.adapters import HTTPAdapter


class IPv6Extractor:
    def __init__(self):
        self.interfaces = []

    def extract_prefix(self, addr: str, netmask: str):
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
                prefix, prefix_bits = self.extract_prefix(addr, netmask)
                self.interfaces.append(
                    {
                        "interface": interface,
                        "addr": addr,
                        "netmask": netmask,
                        "prefix": prefix,
                        "prefix_bits": prefix_bits,
                    }
                )

    def get_prefix(self):
        self.get_network_interfaces()
        interface = self.interfaces[0]
        prefix = interface["prefix"]
        prefix_bits = interface["prefix_bits"]
        logger.note(f"> IPv6 prefix:", end=" ")
        logger.success(f"[{prefix}]", end=" ")
        logger.mesg(f"(/{prefix_bits})")
        return prefix

    def random_ipv6(self, prefix: str = None) -> str:
        if prefix is None:
            prefix = self.get_prefix()
        prefix_segs = prefix.split(":")
        suffix_seg_count = 8 - len(prefix_segs)
        suffix_seg = [f"{random.randint(0, 65535):x}" for _ in range(suffix_seg_count)]
        addr = ":".join(prefix_segs + suffix_seg)
        return addr


class IPv6Adapter(HTTPAdapter):
    def __init__(self, source_address, *args, **kwargs):
        self.source_address = source_address
        super().__init__(*args, **kwargs)

    def init_poolmanager(self, *args, **kwargs):
        kwargs["source_address"] = self.source_address
        return super().init_poolmanager(*args, **kwargs)


class IPTester:
    def __init__(self):
        self.url = "http://ifconfig.me/ip"

    def force_ipv4(self):
        urllib3_cn.allowed_gai_family = lambda: socket.AF_INET

    def force_ipv6(self):
        if urllib3_cn.HAS_IPV6:
            urllib3_cn.allowed_gai_family = lambda: socket.AF_INET6

    def check_ip_addr(self, ip: str = None):
        if not ip:
            return 4

        try:
            socket.inet_pton(socket.AF_INET6, ip)
            return 6
        except Exception as e:
            logger.warn(f"× Invalid ip string: [{ip}]")
            return None

    def set_session_adapter(self, session: requests.Session, ip: str = None):
        ip_version = self.check_ip_addr(ip)
        if ip_version == 4:
            self.force_ipv4()
        elif ip_version == 6:
            self.force_ipv6()
            adapter = IPv6Adapter((ip, 0))
            session.mount("http://", adapter)
            session.mount("https://", adapter)
        else:
            pass

    def get(self, ip: str = None):
        session = requests.Session()
        self.set_session_adapter(session, ip)
        logger.note(f"  > Set:", end=" ")
        if not ip:
            logger.line(f"[ipv4]")
        else:
            logger.line(f"[{ip}]")
        try:
            resp = session.get(self.url, timeout=5)
            if resp and resp.status_code == 200:
                logger.file(f"  * Get:", end=" ")
                logger.success(f"[{resp.text.strip()}]")
        except Exception as e:
            logger.error(f"× Error: {e}")


if __name__ == "__main__":
    extractor = IPv6Extractor()
    prefix = extractor.get_prefix()
    random_ipv6_addrs = [extractor.random_ipv6(prefix) for _ in range(5)]

    ip_tester = IPTester()
    ip_tester.get()
    for ip in random_ipv6_addrs:
        ip_tester.get(ip)
