use std::fmt;

/// MACアドレス（6バイト）を表現する型
///
/// # Examples
/// ```
/// use rust_tcp_tdd::ethernet::MacAddress;
/// let mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
/// assert_eq!(format!("{}", mac), "00:11:22:33:44:55");
/// ```
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MacAddress(pub [u8; 6]);

impl MacAddress {
    /// 新しいMACアドレスを作成
    pub fn new(bytes: [u8; 6]) -> Self {
        MacAddress(bytes)
    }

    /// ブロードキャストアドレス（ff:ff:ff:ff:ff:ff）を返す
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

#[cfg(test)]
mod tests {
    use super::*;

    /// テスト階層: Ethernet > MACアドレス > 基本操作
    mod mac_address {
        use super::*;

        #[test]
        fn 新しいmacアドレスを作成できる() {
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
            assert_eq!(format!("{}", broadcast), "ff:ff:ff:ff:ff:ff");
        }

        #[test]
        fn macアドレスの等価性を判定できる() {
            let mac1 = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
            let mac2 = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
            let mac3 = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x66]);

            assert_eq!(mac1, mac2);
            assert_ne!(mac1, mac3);
        }
    }
}
