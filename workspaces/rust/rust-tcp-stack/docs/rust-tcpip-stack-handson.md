# RustでTCP/IPスタックを実装する - ハンズオン

このハンズオンでは、Rustを使って基礎的なTCP/IPスタックを段階的に実装していきます。ネットワークの低レイヤーを理解し、実際に動作するTCPエコーサーバーを作ることがゴールです。

## 目次

1. [環境セットアップ](#環境セットアップ)
2. [Phase 1: TUN/TAPデバイスの理解](#phase-1-tuntapデバイスの理解)
3. [Phase 2: Ethernetフレームのパース](#phase-2-ethernetフレームのパース)
4. [Phase 3: IPv4パケットの処理](#phase-3-ipv4パケットの処理)
5. [Phase 4: TCP基礎実装](#phase-4-tcp基礎実装)
6. [Phase 5: TCPエコーサーバー完成](#phase-5-tcpエコーサーバー完成)
7. [テストと検証](#テストと検証)

## 前提知識

- Rust基礎（所有権、トレイト、エラーハンドリング）
- TCP/IPの基本的な概念（レイヤー構造、IPアドレス、ポート番号）
- Linuxの基本的なコマンド操作

## 環境セットアップ

### 必要なもの

- Linux環境（Ubuntu 20.04以降推奨、WSL2も可）
- Rust 1.70以上
- root権限（TUN/TAPデバイス操作のため）

### プロジェクト作成

```bash
cargo new rust-tcp-stack
cd rust-tcp-stack
```

### 依存関係の追加

`Cargo.toml`に以下を追加：

```toml
[dependencies]
libc = "0.2"
byteorder = "1.5"
```

### TUN/TAPデバイスとは

TUN/TAPは仮想ネットワークデバイスです：

- **TUN**: レイヤー3（IPパケット）を扱う
- **TAP**: レイヤー2（Ethernetフレーム）を扱う

今回はTAPデバイスを使い、Ethernetフレームから処理します。

## Phase 1: TUN/TAPデバイスの理解

### 1.1 TAPデバイスのオープン

`src/tun_tap.rs`を作成：

```rust
use std::fs::{File, OpenOptions};
use std::io::{self, Read, Write};
use std::os::unix::io::{AsRawFd, RawFd};

const TUNSETIFF: libc::c_ulong = 0x400454ca;
const IFF_TAP: libc::c_short = 0x0002;
const IFF_NO_PI: libc::c_short = 0x1000;

#[repr(C)]
struct IfReq {
    ifr_name: [u8; libc::IF_NAMESIZE],
    ifr_flags: libc::c_short,
    _padding: [u8; 22],
}

pub struct TapDevice {
    file: File,
    name: String,
}

impl TapDevice {
    pub fn new(name: &str) -> io::Result<Self> {
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .open("/dev/net/tun")?;

        let mut ifr = IfReq {
            ifr_name: [0; libc::IF_NAMESIZE],
            ifr_flags: IFF_TAP | IFF_NO_PI,
            _padding: [0; 22],
        };

        // デバイス名をコピー
        let name_bytes = name.as_bytes();
        let copy_len = name_bytes.len().min(libc::IF_NAMESIZE - 1);
        ifr.ifr_name[..copy_len].copy_from_slice(&name_bytes[..copy_len]);

        unsafe {
            if libc::ioctl(file.as_raw_fd(), TUNSETIFF, &ifr) < 0 {
                return Err(io::Error::last_os_error());
            }
        }

        Ok(TapDevice {
            file,
            name: name.to_string(),
        })
    }

    pub fn name(&self) -> &str {
        &self.name
    }

    pub fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        self.file.read(buf)
    }

    pub fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        self.file.write(buf)
    }
}
```

### 1.2 TAPデバイスのテスト

`src/main.rs`：

```rust
mod tun_tap;

use tun_tap::TapDevice;
use std::process::Command;

fn main() -> std::io::Result<()> {
    println!("TAPデバイスを作成中...");
    
    let mut tap = TapDevice::new("tap0")?;
    println!("TAPデバイス作成成功: {}", tap.name());

    // デバイスを有効化
    let output = Command::new("ip")
        .args(&["link", "set", "dev", tap.name(), "up"])
        .output()?;
    
    if !output.status.success() {
        eprintln!("デバイスの有効化に失敗: {:?}", output);
        return Err(std::io::Error::new(
            std::io::ErrorKind::Other,
            "Failed to bring up device"
        ));
    }

    println!("デバイスが有効化されました");
    println!("パケット待機中... (Ctrl+Cで終了)");

    let mut buf = [0u8; 1500];
    loop {
        match tap.read(&mut buf) {
            Ok(n) => {
                println!("受信: {} バイト", n);
                println!("先頭16バイト: {:02x?}", &buf[..16.min(n)]);
            }
            Err(e) => {
                eprintln!("読み取りエラー: {}", e);
                break;
            }
        }
    }

    Ok(())
}
```

### 1.3 実行とテスト

```bash
# root権限で実行
sudo cargo run
```

別のターミナルで：

```bash
# IPアドレスを設定
sudo ip addr add 192.168.100.1/24 dev tap0

# pingを送信
ping 192.168.100.2
```

パケットが受信されることを確認してください。

## Phase 2: Ethernetフレームのパース

### 2.1 Ethernetフレーム構造

```text
+-------------------+-------------------+----------+-------+
| Destination MAC   | Source MAC        | EtherType| Data  |
| (6 bytes)        | (6 bytes)         | (2 bytes)|       |
+-------------------+-------------------+----------+-------+
```

### 2.2 Ethernet実装

`src/ethernet.rs`を作成：

```rust
use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MacAddress(pub [u8; 6]);

impl MacAddress {
    pub fn new(bytes: [u8; 6]) -> Self {
        MacAddress(bytes)
    }

    pub fn broadcast() -> Self {
        MacAddress([0xff; 6])
    }
}

impl fmt::Display for MacAddress {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "{:02x}:{:02x}:{:02x}:{:02x}:{:02x}:{:02x}",
            self.0[0], self.0[1], self.0[2], self.0[3], self.0[4], self.0[5]
        )
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EtherType {
    Ipv4,
    Arp,
    Unknown(u16),
}

impl From<u16> for EtherType {
    fn from(value: u16) -> Self {
        match value {
            0x0800 => EtherType::Ipv4,
            0x0806 => EtherType::Arp,
            _ => EtherType::Unknown(value),
        }
    }
}

impl From<EtherType> for u16 {
    fn from(value: EtherType) -> Self {
        match value {
            EtherType::Ipv4 => 0x0800,
            EtherType::Arp => 0x0806,
            EtherType::Unknown(v) => v,
        }
    }
}

pub struct EthernetFrame<'a> {
    data: &'a [u8],
}

impl<'a> EthernetFrame<'a> {
    pub fn new(data: &'a [u8]) -> Option<Self> {
        if data.len() < 14 {
            return None;
        }
        Some(EthernetFrame { data })
    }

    pub fn destination(&self) -> MacAddress {
        let mut bytes = [0u8; 6];
        bytes.copy_from_slice(&self.data[0..6]);
        MacAddress(bytes)
    }

    pub fn source(&self) -> MacAddress {
        let mut bytes = [0u8; 6];
        bytes.copy_from_slice(&self.data[6..12]);
        MacAddress(bytes)
    }

    pub fn ether_type(&self) -> EtherType {
        let value = u16::from_be_bytes([self.data[12], self.data[13]]);
        EtherType::from(value)
    }

    pub fn payload(&self) -> &[u8] {
        &self.data[14..]
    }
}

pub struct EthernetFrameBuilder {
    buffer: Vec<u8>,
}

impl EthernetFrameBuilder {
    pub fn new(dst: MacAddress, src: MacAddress, ether_type: EtherType) -> Self {
        let mut buffer = Vec::with_capacity(1514);
        buffer.extend_from_slice(&dst.0);
        buffer.extend_from_slice(&src.0);
        let et: u16 = ether_type.into();
        buffer.extend_from_slice(&et.to_be_bytes());
        
        EthernetFrameBuilder { buffer }
    }

    pub fn payload(mut self, data: &[u8]) -> Self {
        self.buffer.extend_from_slice(data);
        self
    }

    pub fn build(self) -> Vec<u8> {
        self.buffer
    }
}
```

### 2.3 Ethernetフレームのパーステスト

`src/main.rs`を更新：

```rust
mod tun_tap;
mod ethernet;

use tun_tap::TapDevice;
use ethernet::EthernetFrame;
use std::process::Command;

fn main() -> std::io::Result<()> {
    println!("TAPデバイスを作成中...");
    
    let mut tap = TapDevice::new("tap0")?;
    println!("TAPデバイス作成成功: {}", tap.name());

    // デバイスを有効化
    Command::new("ip")
        .args(&["link", "set", "dev", tap.name(), "up"])
        .output()?;
    
    Command::new("ip")
        .args(&["addr", "add", "192.168.100.1/24", "dev", tap.name()])
        .output()?;

    println!("デバイスが有効化されました");
    println!("パケット待機中...");

    let mut buf = [0u8; 1500];
    loop {
        match tap.read(&mut buf) {
            Ok(n) => {
                if let Some(frame) = EthernetFrame::new(&buf[..n]) {
                    println!("\n--- Ethernetフレーム受信 ---");
                    println!("送信元MAC: {}", frame.source());
                    println!("宛先MAC: {}", frame.destination());
                    println!("EtherType: {:?}", frame.ether_type());
                    println!("ペイロード長: {} バイト", frame.payload().len());
                }
            }
            Err(e) => {
                eprintln!("読み取りエラー: {}", e);
                break;
            }
        }
    }

    Ok(())
}
```

## Phase 3: IPv4パケットの処理

### 3.1 IPv4ヘッダー構造

```text
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|Version|  IHL  |Type of Service|          Total Length         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|         Identification        |Flags|      Fragment Offset    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  Time to Live |    Protocol   |         Header Checksum       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       Source Address                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Destination Address                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 3.2 IPv4実装

`src/ipv4.rs`を作成：

```rust
use std::net::Ipv4Addr;
use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IpProtocol {
    Tcp,
    Udp,
    Icmp,
    Unknown(u8),
}

impl From<u8> for IpProtocol {
    fn from(value: u8) -> Self {
        match value {
            6 => IpProtocol::Tcp,
            17 => IpProtocol::Udp,
            1 => IpProtocol::Icmp,
            _ => IpProtocol::Unknown(value),
        }
    }
}

impl From<IpProtocol> for u8 {
    fn from(value: IpProtocol) -> Self {
        match value {
            IpProtocol::Tcp => 6,
            IpProtocol::Udp => 17,
            IpProtocol::Icmp => 1,
            IpProtocol::Unknown(v) => v,
        }
    }
}

pub struct Ipv4Packet<'a> {
    data: &'a [u8],
}

impl<'a> Ipv4Packet<'a> {
    pub fn new(data: &'a [u8]) -> Option<Self> {
        if data.len() < 20 {
            return None;
        }
        
        let version = data[0] >> 4;
        if version != 4 {
            return None;
        }

        Some(Ipv4Packet { data })
    }

    pub fn version(&self) -> u8 {
        self.data[0] >> 4
    }

    pub fn header_length(&self) -> usize {
        ((self.data[0] & 0x0f) * 4) as usize
    }

    pub fn total_length(&self) -> u16 {
        u16::from_be_bytes([self.data[2], self.data[3]])
    }

    pub fn protocol(&self) -> IpProtocol {
        IpProtocol::from(self.data[9])
    }

    pub fn source(&self) -> Ipv4Addr {
        Ipv4Addr::new(self.data[12], self.data[13], self.data[14], self.data[15])
    }

    pub fn destination(&self) -> Ipv4Addr {
        Ipv4Addr::new(self.data[16], self.data[17], self.data[18], self.data[19])
    }

    pub fn payload(&self) -> &[u8] {
        let header_len = self.header_length();
        &self.data[header_len..]
    }

    pub fn checksum(&self) -> u16 {
        u16::from_be_bytes([self.data[10], self.data[11]])
    }

    pub fn verify_checksum(&self) -> bool {
        let header_len = self.header_length();
        calculate_checksum(&self.data[..header_len]) == 0
    }
}

pub fn calculate_checksum(data: &[u8]) -> u16 {
    let mut sum: u32 = 0;
    
    for i in (0..data.len()).step_by(2) {
        let word = if i + 1 < data.len() {
            u16::from_be_bytes([data[i], data[i + 1]]) as u32
        } else {
            (data[i] as u32) << 8
        };
        sum += word;
    }

    while (sum >> 16) != 0 {
        sum = (sum & 0xffff) + (sum >> 16);
    }

    !sum as u16
}

pub struct Ipv4PacketBuilder {
    source: Ipv4Addr,
    destination: Ipv4Addr,
    protocol: IpProtocol,
    payload: Vec<u8>,
}

impl Ipv4PacketBuilder {
    pub fn new(source: Ipv4Addr, destination: Ipv4Addr, protocol: IpProtocol) -> Self {
        Ipv4PacketBuilder {
            source,
            destination,
            protocol,
            payload: Vec::new(),
        }
    }

    pub fn payload(mut self, data: &[u8]) -> Self {
        self.payload = data.to_vec();
        self
    }

    pub fn build(self) -> Vec<u8> {
        let total_length = 20 + self.payload.len();
        let mut packet = vec![0u8; total_length];

        // Version (4) + IHL (5 = 20 bytes)
        packet[0] = 0x45;
        
        // Total Length
        packet[2..4].copy_from_slice(&(total_length as u16).to_be_bytes());
        
        // TTL
        packet[8] = 64;
        
        // Protocol
        packet[9] = self.protocol.into();
        
        // Source IP
        packet[12..16].copy_from_slice(&self.source.octets());
        
        // Destination IP
        packet[16..20].copy_from_slice(&self.destination.octets());
        
        // Calculate checksum
        let checksum = calculate_checksum(&packet[..20]);
        packet[10..12].copy_from_slice(&checksum.to_be_bytes());
        
        // Payload
        packet[20..].copy_from_slice(&self.payload);

        packet
    }
}
```

### 3.3 IPv4パケットのテスト

`src/main.rs`を更新：

```rust
mod tun_tap;
mod ethernet;
mod ipv4;

use tun_tap::TapDevice;
use ethernet::{EthernetFrame, EtherType};
use ipv4::Ipv4Packet;
use std::process::Command;

fn main() -> std::io::Result<()> {
    println!("TAPデバイスを作成中...");
    
    let mut tap = TapDevice::new("tap0")?;
    println!("TAPデバイス作成成功: {}", tap.name());

    Command::new("ip")
        .args(&["link", "set", "dev", tap.name(), "up"])
        .output()?;
    
    Command::new("ip")
        .args(&["addr", "add", "192.168.100.1/24", "dev", tap.name()])
        .output()?;

    println!("パケット待機中...");

    let mut buf = [0u8; 1500];
    loop {
        match tap.read(&mut buf) {
            Ok(n) => {
                if let Some(frame) = EthernetFrame::new(&buf[..n]) {
                    if frame.ether_type() == EtherType::Ipv4 {
                        if let Some(packet) = Ipv4Packet::new(frame.payload()) {
                            println!("\n--- IPv4パケット受信 ---");
                            println!("送信元IP: {}", packet.source());
                            println!("宛先IP: {}", packet.destination());
                            println!("プロトコル: {:?}", packet.protocol());
                            println!("チェックサム検証: {}", packet.verify_checksum());
                        }
                    }
                }
            }
            Err(e) => {
                eprintln!("読み取りエラー: {}", e);
                break;
            }
        }
    }

    Ok(())
}
```

## Phase 4: TCP基礎実装

### 4.1 TCPヘッダー構造

```text
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          Source Port          |       Destination Port        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        Sequence Number                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Acknowledgment Number                      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  Data |           |U|A|P|R|S|F|                               |
| Offset| Reserved  |R|C|S|S|Y|I|            Window             |
|       |           |G|K|H|T|N|N|                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|           Checksum            |         Urgent Pointer        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 4.2 TCP実装

`src/tcp.rs`を作成：

```rust
use std::net::Ipv4Addr;

#[derive(Debug, Clone, Copy)]
pub struct TcpFlags {
    pub fin: bool,
    pub syn: bool,
    pub rst: bool,
    pub psh: bool,
    pub ack: bool,
    pub urg: bool,
}

impl TcpFlags {
    pub fn new() -> Self {
        TcpFlags {
            fin: false,
            syn: false,
            rst: false,
            psh: false,
            ack: false,
            urg: false,
        }
    }

    pub fn from_byte(byte: u8) -> Self {
        TcpFlags {
            fin: (byte & 0x01) != 0,
            syn: (byte & 0x02) != 0,
            rst: (byte & 0x04) != 0,
            psh: (byte & 0x08) != 0,
            ack: (byte & 0x10) != 0,
            urg: (byte & 0x20) != 0,
        }
    }

    pub fn to_byte(&self) -> u8 {
        let mut byte = 0u8;
        if self.fin { byte |= 0x01; }
        if self.syn { byte |= 0x02; }
        if self.rst { byte |= 0x04; }
        if self.psh { byte |= 0x08; }
        if self.ack { byte |= 0x10; }
        if self.urg { byte |= 0x20; }
        byte
    }
}

pub struct TcpPacket<'a> {
    data: &'a [u8],
}

impl<'a> TcpPacket<'a> {
    pub fn new(data: &'a [u8]) -> Option<Self> {
        if data.len() < 20 {
            return None;
        }
        Some(TcpPacket { data })
    }

    pub fn source_port(&self) -> u16 {
        u16::from_be_bytes([self.data[0], self.data[1]])
    }

    pub fn destination_port(&self) -> u16 {
        u16::from_be_bytes([self.data[2], self.data[3]])
    }

    pub fn sequence_number(&self) -> u32 {
        u32::from_be_bytes([self.data[4], self.data[5], self.data[6], self.data[7]])
    }

    pub fn acknowledgment_number(&self) -> u32 {
        u32::from_be_bytes([self.data[8], self.data[9], self.data[10], self.data[11]])
    }

    pub fn data_offset(&self) -> usize {
        ((self.data[12] >> 4) * 4) as usize
    }

    pub fn flags(&self) -> TcpFlags {
        TcpFlags::from_byte(self.data[13])
    }

    pub fn window_size(&self) -> u16 {
        u16::from_be_bytes([self.data[14], self.data[15]])
    }

    pub fn checksum(&self) -> u16 {
        u16::from_be_bytes([self.data[16], self.data[17]])
    }

    pub fn payload(&self) -> &[u8] {
        let offset = self.data_offset();
        &self.data[offset..]
    }

    pub fn verify_checksum(&self, src_ip: Ipv4Addr, dst_ip: Ipv4Addr) -> bool {
        calculate_tcp_checksum(self.data, src_ip, dst_ip) == 0
    }
}

pub struct TcpPacketBuilder {
    source_port: u16,
    destination_port: u16,
    sequence_number: u32,
    acknowledgment_number: u32,
    flags: TcpFlags,
    window_size: u16,
    payload: Vec<u8>,
}

impl TcpPacketBuilder {
    pub fn new(source_port: u16, destination_port: u16) -> Self {
        TcpPacketBuilder {
            source_port,
            destination_port,
            sequence_number: 0,
            acknowledgment_number: 0,
            flags: TcpFlags::new(),
            window_size: 65535,
            payload: Vec::new(),
        }
    }

    pub fn sequence_number(mut self, seq: u32) -> Self {
        self.sequence_number = seq;
        self
    }

    pub fn acknowledgment_number(mut self, ack: u32) -> Self {
        self.acknowledgment_number = ack;
        self
    }

    pub fn flags(mut self, flags: TcpFlags) -> Self {
        self.flags = flags;
        self
    }

    pub fn window_size(mut self, window: u16) -> Self {
        self.window_size = window;
        self
    }

    pub fn payload(mut self, data: &[u8]) -> Self {
        self.payload = data.to_vec();
        self
    }

    pub fn build(self, src_ip: Ipv4Addr, dst_ip: Ipv4Addr) -> Vec<u8> {
        let header_len = 20;
        let total_len = header_len + self.payload.len();
        let mut packet = vec![0u8; total_len];

        // Source port
        packet[0..2].copy_from_slice(&self.source_port.to_be_bytes());
        
        // Destination port
        packet[2..4].copy_from_slice(&self.destination_port.to_be_bytes());
        
        // Sequence number
        packet[4..8].copy_from_slice(&self.sequence_number.to_be_bytes());
        
        // Acknowledgment number
        packet[8..12].copy_from_slice(&self.acknowledgment_number.to_be_bytes());
        
        // Data offset (5 * 4 = 20 bytes)
        packet[12] = 5 << 4;
        
        // Flags
        packet[13] = self.flags.to_byte();
        
        // Window size
        packet[14..16].copy_from_slice(&self.window_size.to_be_bytes());
        
        // Payload
        packet[20..].copy_from_slice(&self.payload);
        
        // Calculate checksum
        let checksum = calculate_tcp_checksum(&packet, src_ip, dst_ip);
        packet[16..18].copy_from_slice(&checksum.to_be_bytes());

        packet
    }
}

fn calculate_tcp_checksum(tcp_data: &[u8], src_ip: Ipv4Addr, dst_ip: Ipv4Addr) -> u16 {
    let mut sum: u32 = 0;

    // Pseudo header
    for &byte in src_ip.octets().iter() {
        sum += byte as u32;
    }
    for &byte in dst_ip.octets().iter() {
        sum += byte as u32;
    }
    sum += 6; // Protocol (TCP)
    sum += tcp_data.len() as u32;

    // TCP header and data
    for i in (0..tcp_data.len()).step_by(2) {
        let word = if i + 1 < tcp_data.len() {
            u16::from_be_bytes([tcp_data[i], tcp_data[i + 1]]) as u32
        } else {
            (tcp_data[i] as u32) << 8
        };
        sum += word;
    }

    while (sum >> 16) != 0 {
        sum = (sum & 0xffff) + (sum >> 16);
    }

    !sum as u16
}
```

## Phase 5: TCPエコーサーバー完成

### 5.1 TCP接続管理

`src/tcp_connection.rs`を作成：

```rust
use std::collections::HashMap;
use std::net::Ipv4Addr;
use crate::tcp::{TcpFlags, TcpPacket, TcpPacketBuilder};
use crate::ipv4::Ipv4PacketBuilder;
use crate::ethernet::{EthernetFrameBuilder, MacAddress, EtherType};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TcpState {
    Listen,
    SynReceived,
    Established,
    FinWait1,
    FinWait2,
    TimeWait,
    Closed,
}

pub struct TcpConnection {
    state: TcpState,
    local_seq: u32,
    remote_seq: u32,
    local_addr: Ipv4Addr,
    remote_addr: Ipv4Addr,
    local_port: u16,
    remote_port: u16,
}

impl TcpConnection {
    pub fn new(
        local_addr: Ipv4Addr,
        remote_addr: Ipv4Addr,
        local_port: u16,
        remote_port: u16,
    ) -> Self {
        TcpConnection {
            state: TcpState::Listen,
            local_seq: 1000, // 初期シーケンス番号（本来はランダム）
            remote_seq: 0,
            local_addr,
            remote_addr,
            local_port,
            remote_port,
        }
    }

    pub fn handle_packet(
        &mut self,
        tcp_packet: &TcpPacket,
        src_mac: MacAddress,
        dst_mac: MacAddress,
    ) -> Option<Vec<u8>> {
        let flags = tcp_packet.flags();

        match self.state {
            TcpState::Listen => {
                if flags.syn {
                    println!("SYN受信 - SYN-ACKを送信");
                    self.remote_seq = tcp_packet.sequence_number();
                    self.state = TcpState::SynReceived;
                    
                    let mut response_flags = TcpFlags::new();
                    response_flags.syn = true;
                    response_flags.ack = true;

                    return Some(self.build_response(
                        src_mac,
                        dst_mac,
                        response_flags,
                        self.remote_seq + 1,
                        &[],
                    ));
                }
            }
            TcpState::SynReceived => {
                if flags.ack {
                    println!("ACK受信 - 接続確立");
                    self.local_seq += 1;
                    self.state = TcpState::Established;
                }
            }
            TcpState::Established => {
                if flags.fin {
                    println!("FIN受信 - 接続終了処理開始");
                    self.remote_seq = tcp_packet.sequence_number();
                    self.state = TcpState::FinWait1;

                    let mut response_flags = TcpFlags::new();
                    response_flags.ack = true;
                    response_flags.fin = true;

                    return Some(self.build_response(
                        src_mac,
                        dst_mac,
                        response_flags,
                        self.remote_seq + 1,
                        &[],
                    ));
                }

                let payload = tcp_packet.payload();
                if !payload.is_empty() {
                    println!("データ受信: {} バイト", payload.len());
                    println!("内容: {}", String::from_utf8_lossy(payload));
                    
                    self.remote_seq = tcp_packet.sequence_number();
                    
                    // エコー応答
                    let mut response_flags = TcpFlags::new();
                    response_flags.ack = true;
                    response_flags.psh = true;

                    return Some(self.build_response(
                        src_mac,
                        dst_mac,
                        response_flags,
                        self.remote_seq + payload.len() as u32,
                        payload,
                    ));
                } else if flags.ack {
                    // ACKのみのパケット
                    self.remote_seq = tcp_packet.sequence_number();
                }
            }
            TcpState::FinWait1 => {
                if flags.ack {
                    println!("FIN-ACK完了");
                    self.state = TcpState::Closed;
                }
            }
            _ => {}
        }

        None
    }

    fn build_response(
        &mut self,
        src_mac: MacAddress,
        dst_mac: MacAddress,
        flags: TcpFlags,
        ack_num: u32,
        payload: &[u8],
    ) -> Vec<u8> {
        let tcp_packet = TcpPacketBuilder::new(self.local_port, self.remote_port)
            .sequence_number(self.local_seq)
            .acknowledgment_number(ack_num)
            .flags(flags)
            .payload(payload)
            .build(self.local_addr, self.remote_addr);

        if !payload.is_empty() {
            self.local_seq += payload.len() as u32;
        }

        let ip_packet = Ipv4PacketBuilder::new(
            self.local_addr,
            self.remote_addr,
            crate::ipv4::IpProtocol::Tcp,
        )
        .payload(&tcp_packet)
        .build();

        EthernetFrameBuilder::new(dst_mac, src_mac, EtherType::Ipv4)
            .payload(&ip_packet)
            .build()
    }
}

pub struct TcpListener {
    local_addr: Ipv4Addr,
    local_mac: MacAddress,
    connections: HashMap<(Ipv4Addr, u16), TcpConnection>,
}

impl TcpListener {
    pub fn new(local_addr: Ipv4Addr, local_mac: MacAddress) -> Self {
        TcpListener {
            local_addr,
            local_mac,
            connections: HashMap::new(),
        }
    }

    pub fn handle_packet(
        &mut self,
        tcp_packet: &TcpPacket,
        src_ip: Ipv4Addr,
        dst_ip: Ipv4Addr,
        src_mac: MacAddress,
        dst_mac: MacAddress,
    ) -> Option<Vec<u8>> {
        let key = (src_ip, tcp_packet.source_port());
        
        let connection = self.connections
            .entry(key)
            .or_insert_with(|| {
                TcpConnection::new(
                    self.local_addr,
                    src_ip,
                    tcp_packet.destination_port(),
                    tcp_packet.source_port(),
                )
            });

        connection.handle_packet(tcp_packet, dst_mac, src_mac)
    }
}
```

### 5.2 完成版main.rs

```rust
mod tun_tap;
mod ethernet;
mod ipv4;
mod tcp;
mod tcp_connection;

use tun_tap::TapDevice;
use ethernet::{EthernetFrame, EtherType, MacAddress};
use ipv4::{Ipv4Packet, IpProtocol};
use tcp::TcpPacket;
use tcp_connection::TcpListener;
use std::process::Command;
use std::net::Ipv4Addr;

fn main() -> std::io::Result<()> {
    println!("=== RustでTCP/IPスタック実装 - TCPエコーサーバー ===\n");
    
    // TAPデバイス作成
    let mut tap = TapDevice::new("tap0")?;
    println!("✓ TAPデバイス作成: {}", tap.name());

    // ネットワーク設定
    let local_ip = Ipv4Addr::new(192, 168, 100, 2);
    let local_mac = MacAddress::new([0x02, 0x00, 0x00, 0x00, 0x00, 0x01]);

    Command::new("ip")
        .args(&["link", "set", "dev", tap.name(), "up"])
        .output()?;
    
    Command::new("ip")
        .args(&["addr", "add", "192.168.100.1/24", "dev", tap.name()])
        .output()?;

    println!("✓ ネットワーク設定完了");
    println!("  - デバイスIP: 192.168.100.1/24");
    println!("  - サーバーIP: {}", local_ip);
    println!("  - リスニングポート: 8080\n");

    println!("TCPエコーサーバー起動中...");
    println!("接続方法: nc 192.168.100.2 8080\n");
    println!("--- ログ ---");

    let mut listener = TcpListener::new(local_ip, local_mac);
    let mut buf = [0u8; 1500];

    loop {
        match tap.read(&mut buf) {
            Ok(n) => {
                // Ethernetフレーム解析
                let Some(eth_frame) = EthernetFrame::new(&buf[..n]) else {
                    continue;
                };

                if eth_frame.ether_type() != EtherType::Ipv4 {
                    continue;
                }

                // IPv4パケット解析
                let Some(ip_packet) = Ipv4Packet::new(eth_frame.payload()) else {
                    continue;
                };

                if ip_packet.destination() != local_ip {
                    continue;
                }

                if ip_packet.protocol() != IpProtocol::Tcp {
                    continue;
                }

                // TCPパケット解析
                let Some(tcp_packet) = TcpPacket::new(ip_packet.payload()) else {
                    continue;
                };

                if tcp_packet.destination_port() != 8080 {
                    continue;
                }

                // TCP接続処理
                if let Some(response) = listener.handle_packet(
                    &tcp_packet,
                    ip_packet.source(),
                    ip_packet.destination(),
                    eth_frame.source(),
                    eth_frame.destination(),
                ) {
                    if let Err(e) = tap.write(&response) {
                        eprintln!("送信エラー: {}", e);
                    }
                }
            }
            Err(e) => {
                eprintln!("読み取りエラー: {}", e);
                break;
            }
        }
    }

    Ok(())
}
```

## テストと検証

### 動作確認手順

#### 1. **サーバー起動**

```bash
sudo cargo run
```

#### 2. **別のターミナルで接続テスト**

```bash
# netcatで接続
nc 192.168.100.2 8080

# 何か入力してEnterを押すと、エコーバックされます
Hello, TCP!
Hello, TCP!
```

#### 3. **tcpdumpで通信を確認**

```bash
sudo tcpdump -i tap0 -n -X
```

### 期待される出力

サーバー側：

```text
=== RustでTCP/IPスタック実装 - TCPエコーサーバー ===

✓ TAPデバイス作成: tap0
✓ ネットワーク設定完了
  - デバイスIP: 192.168.100.1/24
  - サーバーIP: 192.168.100.2
  - リスニングポート: 8080

TCPエコーサーバー起動中...
接続方法: nc 192.168.100.2 8080

--- ログ ---
SYN受信 - SYN-ACKを送信
ACK受信 - 接続確立
データ受信: 13 バイト
内容: Hello, TCP!

FIN受信 - 接続終了処理開始
FIN-ACK完了
```

## トラブルシューティング

### "Permission denied" エラー

```bash
# sudoで実行
sudo cargo run

# または、実行ファイルにcapabilityを付与
sudo setcap cap_net_admin=eip target/debug/rust-tcp-stack
```

### デバイスが作成されない

```bash
# TUN/TAPカーネルモジュールをロード
sudo modprobe tun

# デバイスファイルの確認
ls -l /dev/net/tun
```

### 接続できない

```bash
# ルーティングテーブル確認
ip route

# ファイアウォール確認（無効化する場合）
sudo iptables -F
```

## 次のステップ

このハンズオンを完了したら、以下の拡張に挑戦してみてください：

1. **複数接続対応**: 同時に複数のクライアントを処理
2. **再送制御**: パケットロスに対応
3. **ウィンドウ制御**: フロー制御の実装
4. **UDPサポート**: UDP echoサーバーの実装
5. **HTTPサーバー**: 簡単なHTTPレスポンスを返す

## 参考資料

- [RFC 793 - TCP](https://datatracker.ietf.org/doc/html/rfc793)
- [RFC 791 - IP](https://datatracker.ietf.org/doc/html/rfc791)
- [Linux TUN/TAP documentation](https://www.kernel.org/doc/html/latest/networking/tuntap.html)
- [Rust Embedded Book](https://rust-embedded.github.io/book/)

## まとめ

このハンズオンでは以下を学習しました：

- TUN/TAPデバイスの使い方
- Ethernetフレームの構造とパース
- IPv4パケットの構造とチェックサム計算
- TCPの3-wayハンドシェイクと状態管理
- 実際に動作するTCPエコーサーバーの実装

おめでとうございます！あなたは今、ネットワークスタックの基礎を理解し、低レイヤーのプログラミングができるようになりました。
