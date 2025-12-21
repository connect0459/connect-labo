use rust_tcp_stack::ethernet::{EtherType, EthernetFrame, EthernetFrameBuilder, MacAddress};
use rust_tcp_stack::ipv4::{IpProtocol, Ipv4Packet, Ipv4PacketBuilder};
use rust_tcp_stack::tcp::{TcpFlags, TcpPacket, TcpPacketBuilder};
use std::net::Ipv4Addr;

/// Phase 5
#[test]
fn 完全なsynパケットを構築できる() {
    // TCP SYN
    let tcp_segment = TcpPacketBuilder::new()
        .source_port(12345)
        .destination_port(80)
        .sequence_number(1000)
        .flags(TcpFlags::SYN)
        .build_with_checksum(Ipv4Addr::new(192, 168, 1, 1), Ipv4Addr::new(192, 168, 1, 2));

    // IPv4パケット
    let ipv4_packet = Ipv4PacketBuilder::new()
        .source(Ipv4Addr::new(192, 168, 1, 1))
        .destination(Ipv4Addr::new(192, 168, 1, 2))
        .protocol(IpProtocol::Tcp)
        .payload(&tcp_segment)
        .build();

    // Ethernetフレーム
    let ethernet_frame = EthernetFrameBuilder::new()
        .source(MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]))
        .destination(MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]))
        .ether_type(EtherType::Ipv4)
        .payload(&ipv4_packet)
        .build();

    // 全体をパースして検証
    let eth_frame = EthernetFrame::new(&ethernet_frame).unwrap();
    let ip_packet = Ipv4Packet::new(eth_frame.payload()).unwrap();
    let tcp_packet = TcpPacket::new(ip_packet.payload()).unwrap();

    assert_eq!(tcp_packet.source_port(), 12345);
    assert_eq!(tcp_packet.destination_port(), 80);
    assert!(tcp_packet.is_syn());
}

/// Phase 6
#[test]
fn スタック全体をパースできる() {
    // 実際のパケットバイト列を手動で構築
    let mut packet = Vec::new();

    // Ethernetヘッダー
    packet.extend_from_slice(&[0xff, 0xff, 0xff, 0xff, 0xff, 0xff]); // Dst MAC
    packet.extend_from_slice(&[0x00, 0x11, 0x22, 0x33, 0x44, 0x55]); // Src MAC
    packet.extend_from_slice(&[0x08, 0x00]); // EtherType: IPv4

    // IPv4ヘッダー (20バイト)
    packet.extend_from_slice(&[
        0x45, 0x00, 0x00, 0x28, // Version, IHL, ToS, Total Length (40バイト)
        0x00, 0x01, 0x00, 0x00, // Identification, Flags, Fragment Offset
        0x40, 0x06, 0x00, 0x00, // TTL (64), Protocol (TCP=6), Checksum
        0xc0, 0xa8, 0x01, 0x01, // Source IP: 192.168.1.1
        0xc0, 0xa8, 0x01, 0x02, // Destination IP: 192.168.1.2
    ]);

    // チェックサム計算して更新
    let ipv4_checksum = rust_tcp_stack::ipv4::calculate_ipv4_checksum(&packet[14..34]);
    packet[24..26].copy_from_slice(&ipv4_checksum.to_be_bytes());

    // TCPヘッダー (20バイト)
    packet.extend_from_slice(&[
        0x30, 0x39, // Source Port: 12345
        0x00, 0x50, // Destination Port: 80
        0x00, 0x00, 0x03, 0xe8, // Sequence Number: 1000
        0x00, 0x00, 0x00, 0x00, // Acknowledgment Number: 0
        0x50, 0x02, // Data Offset (5), Flags (SYN)
        0xff, 0xff, // Window Size: 65535
        0x00, 0x00, // Checksum
        0x00, 0x00, // Urgent Pointer
    ]);

    // TCPチェックサム計算して更新
    let tcp_checksum = rust_tcp_stack::tcp::calculate_tcp_checksum(
        &packet[34..],
        Ipv4Addr::new(192, 168, 1, 1),
        Ipv4Addr::new(192, 168, 1, 2),
    );
    packet[50..52].copy_from_slice(&tcp_checksum.to_be_bytes());

    // パース
    let eth_frame = EthernetFrame::new(&packet).unwrap();
    assert_eq!(eth_frame.ether_type(), EtherType::Ipv4);

    let ip_packet = Ipv4Packet::new(eth_frame.payload()).unwrap();
    assert_eq!(ip_packet.source(), Ipv4Addr::new(192, 168, 1, 1));
    assert_eq!(ip_packet.destination(), Ipv4Addr::new(192, 168, 1, 2));
    assert_eq!(ip_packet.protocol(), IpProtocol::Tcp);

    let tcp_packet = TcpPacket::new(ip_packet.payload()).unwrap();
    assert_eq!(tcp_packet.source_port(), 12345);
    assert_eq!(tcp_packet.destination_port(), 80);
    assert_eq!(tcp_packet.sequence_number(), 1000);
    assert!(tcp_packet.is_syn());
}

#[test]
fn スタック全体を構築できる() {
    let src_mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    let dst_mac = MacAddress::broadcast();
    let src_ip = Ipv4Addr::new(192, 168, 1, 1);
    let dst_ip = Ipv4Addr::new(192, 168, 1, 2);

    // TCP SYNセグメント
    let tcp_segment = TcpPacketBuilder::new()
        .source_port(12345)
        .destination_port(80)
        .sequence_number(1000)
        .flags(TcpFlags::SYN)
        .build_with_checksum(src_ip, dst_ip);

    // IPv4パケット
    let ipv4_packet = Ipv4PacketBuilder::new()
        .source(src_ip)
        .destination(dst_ip)
        .protocol(IpProtocol::Tcp)
        .payload(&tcp_segment)
        .build();

    // Ethernetフレーム
    let ethernet_frame = EthernetFrameBuilder::new()
        .source(src_mac)
        .destination(dst_mac)
        .ether_type(EtherType::Ipv4)
        .payload(&ipv4_packet)
        .build();

    // パースして検証
    let eth_frame = EthernetFrame::new(&ethernet_frame).unwrap();
    assert_eq!(eth_frame.destination(), dst_mac);
    assert_eq!(eth_frame.source(), src_mac);

    let ip_packet = Ipv4Packet::new(eth_frame.payload()).unwrap();
    assert_eq!(ip_packet.source(), src_ip);
    assert_eq!(ip_packet.destination(), dst_ip);

    let tcp_packet = TcpPacket::new(ip_packet.payload()).unwrap();
    assert_eq!(tcp_packet.source_port(), 12345);
    assert_eq!(tcp_packet.destination_port(), 80);
    assert!(tcp_packet.is_syn());
}
