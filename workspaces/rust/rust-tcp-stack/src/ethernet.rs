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
        match value {
            0x0800 => EtherType::Ipv4,
            0x0806 => EtherType::Arp,
            _ => EtherType::Unknown(value),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn macアドレスを作成できる() {
        let mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
        assert_eq!(mac.0, [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    }

    #[test]
    fn macアドレスを文字列表示できる() {
        let mac = MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
        assert_eq!(format!("{}", mac), "aa:bb:cc:dd:ee:ff");
    }

    #[test]
    fn ブロードキャストアドレスを作成できる() {
        let broadcast = MacAddress::broadcast();
        assert_eq!(broadcast.0, [0xff; 6]);
    }

    #[test]
    fn ethernetフレームは14バイト未満を拒否する() {
        let short_data = [0u8; 13];
        assert!(EthernetFrame::new(&short_data).is_none());
    }

    #[test]
    fn ethernetフレームは14バイト以上を受け入れる() {
        let valid_data = [0u8; 14];
        assert!(EthernetFrame::new(&valid_data).is_some());
    }

    #[test]
    fn 宛先macアドレスを取得できる() {
        let mut data = [0u8; 14];
        data[0..6].copy_from_slice(&[0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);

        let frame = EthernetFrame::new(&data).unwrap();
        let expected = MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
        assert_eq!(frame.destination(), expected);
    }

    #[test]
    fn 送信元macアドレスを取得できる() {
        let mut data = [0u8; 14];
        data[6..12].copy_from_slice(&[0x11, 0x22, 0x33, 0x44, 0x55, 0x66]);

        let frame = EthernetFrame::new(&data).unwrap();
        let expected = MacAddress::new([0x11, 0x22, 0x33, 0x44, 0x55, 0x66]);
        assert_eq!(frame.source(), expected);
    }

    #[test]
    fn ethertypeがipv4の場合() {
        let mut data = [0u8; 14];
        data[12] = 0x08;
        data[13] = 0x00;

        let frame = EthernetFrame::new(&data).unwrap();
        assert_eq!(frame.ether_type(), EtherType::Ipv4);
    }

    #[test]
    fn ethertypeがarpの場合() {
        let mut data = [0u8; 14];
        data[12] = 0x08;
        data[13] = 0x06;

        let frame = EthernetFrame::new(&data).unwrap();
        assert_eq!(frame.ether_type(), EtherType::Arp);
    }
}
