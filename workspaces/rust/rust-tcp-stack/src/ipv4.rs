use std::net::Ipv4Addr;

pub struct Ipv4Packet<'a> {
    data: &'a [u8],
}

impl<'a> Ipv4Packet<'a> {
    pub fn new(data: &'a [u8]) -> Option<Self> {
        if data.len() < 20 {
            return None;
        }

        // シフト演算子で上位4bitを取得
        let version = data[0] >> 4;
        if version != 4 {
            return None;
        }

        Some(Ipv4Packet { data })
    }

    pub fn source(&self) -> Ipv4Addr {
        Ipv4Addr::new(
            self.data[12],
            self.data[13],
            self.data[14],
            self.data[15],
        )
    }

    pub fn destination(&self) -> Ipv4Addr {
        Ipv4Addr::new(
            self.data[16],
            self.data[17],
            self.data[18],
            self.data[19],
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ipv4パケットは20バイト未満を拒否する() {
        let short_data = [0u8; 19];
        assert!(Ipv4Packet::new(&short_data).is_none());
    }

    #[test]
    fn バージョンが4でない場合は拒否する() {
        let mut data = [0u8; 20];
        data[0] = 0x60; // バージョン6(IPv6)
        assert!(Ipv4Packet::new(&data).is_none());
    }

    #[test]
    fn 送信元ipアドレスを取得できる() {
        let mut data = [0u8; 20];
        data[0] = 0x45; // バージョン4, IHL=5
        data[12..16].copy_from_slice(&[192, 168, 1, 1]);

        let packet = Ipv4Packet::new(&data).unwrap();
        assert_eq!(packet.source(), Ipv4Addr::new(192, 168, 1, 1));
    }

    #[test]
    fn 宛先ipアドレスを取得できる() {
        let mut data = [0u8; 20];
        data[0] = 0x45; // バージョン4, IHL=5
        data[16..20].copy_from_slice(&[10, 0, 0, 1]);

        let packet = Ipv4Packet::new(&data).unwrap();
        assert_eq!(packet.destination(), Ipv4Addr::new(10, 0, 0, 1));
    }
}
