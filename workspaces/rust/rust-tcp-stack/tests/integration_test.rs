use rust_tcp_stack::ethernet::{EtherType, EthernetFrame, EthernetFrameBuilder, MacAddress};
use rust_tcp_stack::ipv4::{IpProtocol, Ipv4Packet, Ipv4PacketBuilder};
use rust_tcp_stack::tcp::{TcpFlags, TcpPacket, TcpPacketBuilder};
use std::net::Ipv4Addr;

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
