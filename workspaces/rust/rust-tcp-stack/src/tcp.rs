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
}

#[cfg(test)]
mod tests {
    use super::*;

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
}
