use std::net::Ipv4Addr;

pub fn calculate_tcp_checksum(tcp_segment: &[u8], src_ip: Ipv4Addr, dst_ip: Ipv4Addr) -> u16 {
    let mut sum: u32 = 0;

    // 疑似ヘッダーの追加
    for &byte in src_ip.octets().iter() {
        sum += byte as u32;
    }
    for &byte in dst_ip.octets().iter() {
        sum += byte as u32;
    }
    sum += 6; // Protocol: TCP
    sum += tcp_segment.len() as u32;

    // TCPセグメント全体を16ビットワードで加算
    for i in (0..tcp_segment.len()).step_by(2) {
        let word = if i + 1 < tcp_segment.len() {
            u16::from_be_bytes([tcp_segment[i], tcp_segment[i + 1]]) as u32
        } else {
            (tcp_segment[i] as u32) << 8
        };
        sum += word;
    }

    // キャリーを折り返す
    while (sum >> 16) != 0 {
        sum = (sum & 0xffff) + (sum >> 16);
    }

    // 1の補数を取る
    !(sum as u16)
}

pub struct TcpFlags {
    pub syn: bool,
    pub ack: bool,
    pub fin: bool,
    pub rst: bool,
}

impl TcpFlags {
    pub const SYN: Self = TcpFlags {
        syn: true,
        ack: false,
        fin: false,
        rst: false,
    };

    pub const SYN_ACK: Self = TcpFlags {
        syn: true,
        ack: true,
        fin: false,
        rst: false,
    };

    pub const ACK: Self = TcpFlags {
        syn: false,
        ack: true,
        fin: false,
        rst: false,
    };

    pub const FIN_ACK: Self = TcpFlags {
        syn: false,
        ack: true,
        fin: true,
        rst: false,
    };

    fn to_byte(&self) -> u8 {
        let mut flags = 0u8;
        if self.fin {
            flags |= 0x01;
        }
        if self.syn {
            flags |= 0x02;
        }
        if self.rst {
            flags |= 0x04;
        }
        if self.ack {
            flags |= 0x10;
        }
        flags
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
    pub fn new() -> Self {
        TcpPacketBuilder {
            source_port: 0,
            destination_port: 0,
            sequence_number: 0,
            acknowledgment_number: 0,
            flags: TcpFlags::ACK,
            window_size: 65535,
            payload: Vec::new(),
        }
    }

    pub fn source_port(mut self, port: u16) -> Self {
        self.source_port = port;
        self
    }

    pub fn destination_port(mut self, port: u16) -> Self {
        self.destination_port = port;
        self
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

    pub fn build(self) -> Vec<u8> {
        let total_length = 20 + self.payload.len();
        let mut bytes = vec![0u8; total_length];

        // Source Port
        bytes[0..2].copy_from_slice(&self.source_port.to_be_bytes());

        // Destination Port
        bytes[2..4].copy_from_slice(&self.destination_port.to_be_bytes());

        // Sequence Number
        bytes[4..8].copy_from_slice(&self.sequence_number.to_be_bytes());

        // Acknowledgment Number
        bytes[8..12].copy_from_slice(&self.acknowledgment_number.to_be_bytes());

        // Data Offset (5 = 20 bytes) + Reserved
        bytes[12] = 0x50;

        // Flags
        bytes[13] = self.flags.to_byte();

        // Window Size
        bytes[14..16].copy_from_slice(&self.window_size.to_be_bytes());

        // Checksum (0で初期化、後で計算する場合は別途)
        bytes[16..18].copy_from_slice(&[0, 0]);

        // Payload
        bytes[20..].copy_from_slice(&self.payload);

        bytes
    }

    // 疑似ヘッダーを使ったチェックサム付きビルド
    pub fn build_with_checksum(self, src_ip: Ipv4Addr, dst_ip: Ipv4Addr) -> Vec<u8> {
        let mut bytes = self.build();

        // チェックサム計算
        let checksum = super::tcp::calculate_tcp_checksum(&bytes, src_ip, dst_ip);
        bytes[16..18].copy_from_slice(&checksum.to_be_bytes());

        bytes
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

    pub fn is_syn(&self) -> bool {
        (self.data[13] & 0x02) != 0
    }

    pub fn is_ack(&self) -> bool {
        (self.data[13] & 0x10) != 0
    }

    pub fn is_fin(&self) -> bool {
        (self.data[13] & 0x01) != 0
    }

    pub fn is_rst(&self) -> bool {
        (self.data[13] & 0x04) != 0
    }

    pub fn window_size(&self) -> u16 {
        u16::from_be_bytes([self.data[14], self.data[15]])
    }

    pub fn header_length(&self) -> usize {
        let data_offset = (self.data[12] >> 4) as usize;
        data_offset * 4
    }

    pub fn payload(&self) -> &[u8] {
        let header_len = self.header_length();
        &self.data[header_len..]
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::Ipv4Addr;

    #[test]
    fn tcpパケットは20バイト未満を拒否する() {
        let short_data = [0u8; 19];
        assert!(TcpPacket::new(&short_data).is_none());
    }

    #[test]
    fn 送信元ポート番号を取得できる() {
        let mut data = [0u8; 20];
        data[0] = 0x00;
        data[1] = 0x50; // ポート80 (HTTP)

        let packet = TcpPacket::new(&data).unwrap();
        assert_eq!(packet.source_port(), 80);
    }

    #[test]
    fn 宛先ポート番号を取得できる() {
        let mut data = [0u8; 20];
        data[2] = 0x1f;
        data[3] = 0x90; // ポート8080

        let packet = TcpPacket::new(&data).unwrap();
        assert_eq!(packet.destination_port(), 8080);
    }

    #[test]
    fn シーケンス番号を取得できる() {
        let mut data = [0u8; 20];
        data[4..8].copy_from_slice(&[0x00, 0x00, 0x00, 0x64]); // 100

        let packet = TcpPacket::new(&data).unwrap();
        assert_eq!(packet.sequence_number(), 100);
    }

    #[test]
    fn 確認応答番号を取得できる() {
        let mut data = [0u8; 20];
        data[8..12].copy_from_slice(&[0x00, 0x00, 0x00, 0xc9]); // 201

        let packet = TcpPacket::new(&data).unwrap();
        assert_eq!(packet.acknowledgment_number(), 201);
    }

    #[test]
    fn synフラグを判定できる() {
        let mut data = [0u8; 20];
        data[13] = 0x02; // SYNフラグ

        let packet = TcpPacket::new(&data).unwrap();
        assert!(packet.is_syn());
        assert!(!packet.is_ack());
    }

    #[test]
    fn ackフラグを判定できる() {
        let mut data = [0u8; 20];
        data[13] = 0x10; // ACKフラグ

        let packet = TcpPacket::new(&data).unwrap();
        assert!(packet.is_ack());
        assert!(!packet.is_syn());
    }

    #[test]
    fn syn_ackフラグを判定できる() {
        let mut data = [0u8; 20];
        data[13] = 0x12; // SYN + ACKフラグ

        let packet = TcpPacket::new(&data).unwrap();
        assert!(packet.is_syn());
        assert!(packet.is_ack());
    }

    #[test]
    fn finフラグを判定できる() {
        let mut data = [0u8; 20];
        data[13] = 0x01; // FINフラグ

        let packet = TcpPacket::new(&data).unwrap();
        assert!(packet.is_fin());
    }

    #[test]
    fn ウィンドウサイズを取得できる() {
        let mut data = [0u8; 20];
        data[14] = 0xff;
        data[15] = 0xff; // 65535

        let packet = TcpPacket::new(&data).unwrap();
        assert_eq!(packet.window_size(), 65535);
    }

    #[test]
    fn ペイロードを取得できる() {
        let mut data = vec![0u8; 30];
        data[12] = 0x50; // Data Offset = 5 (20バイト)
        data[20..30].copy_from_slice(b"HelloWorld");

        let packet = TcpPacket::new(&data).unwrap();
        assert_eq!(packet.payload(), b"HelloWorld");
    }

    #[test]
    fn チェックサムを計算できる() {
        let tcp_data = vec![
            0x00, 0x50, // Source Port: 80
            0x1f, 0x90, // Destination Port: 8080
            0x00, 0x00, 0x00, 0x64, // Sequence: 100
            0x00, 0x00, 0x00, 0x00, // Acknowledgment: 0
            0x50, 0x02, // Data Offset: 5, Flags: SYN
            0xff, 0xff, // Window: 65535
            0x00, 0x00, // Checksum: 0 (計算前)
            0x00, 0x00, // Urgent Pointer: 0
        ];

        let src_ip = Ipv4Addr::new(192, 168, 1, 1);
        let dst_ip = Ipv4Addr::new(192, 168, 1, 2);

        let checksum = calculate_tcp_checksum(&tcp_data, src_ip, dst_ip);
        assert_ne!(checksum, 0);
    }

    #[test]
    fn tcpセグメントを構築できる() {
        let src_port = 12345;
        let dst_port = 80;
        let seq = 100;
        let ack = 0;

        let segment_bytes = TcpPacketBuilder::new()
            .source_port(src_port)
            .destination_port(dst_port)
            .sequence_number(seq)
            .acknowledgment_number(ack)
            .flags(TcpFlags::SYN)
            .build();

        // パース
        let segment = TcpPacket::new(&segment_bytes).unwrap();

        // 検証
        assert_eq!(segment.source_port(), src_port);
        assert_eq!(segment.destination_port(), dst_port);
        assert_eq!(segment.sequence_number(), seq);
        assert!(segment.is_syn());
        assert!(!segment.is_ack());
    }
}
