use vte::{Params, Parser, Perform};

/// Parser handler that processes ANSI escape sequences
pub struct AnsiParser {
    parser: Parser,
}

impl AnsiParser {
    pub fn new() -> Self {
        Self {
            parser: Parser::new(),
        }
    }

    /// Process incoming bytes from PTY
    pub fn advance<P: Perform>(&mut self, performer: &mut P, byte: u8) {
        self.parser.advance(performer, byte);
    }
}

impl Default for AnsiParser {
    fn default() -> Self {
        Self::new()
    }
}

/// Helper to convert vte Params to a slice
pub fn params_to_vec(params: &Params) -> Vec<i64> {
    let mut result = Vec::new();
    for param in params {
        for &value in param {
            result.push(value as i64);
        }
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use vte::Perform;

    struct TestPerformer {
        pub printed_chars: Vec<char>,
        pub csi_commands: Vec<(Vec<i64>, char)>,
    }

    impl TestPerformer {
        fn new() -> Self {
            Self {
                printed_chars: Vec::new(),
                csi_commands: Vec::new(),
            }
        }
    }

    impl Perform for TestPerformer {
        fn print(&mut self, c: char) {
            self.printed_chars.push(c);
        }

        fn execute(&mut self, _byte: u8) {
            // Handle control characters
        }

        fn hook(&mut self, _params: &Params, _intermediates: &[u8], _ignore: bool, _c: char) {}

        fn put(&mut self, _byte: u8) {}

        fn unhook(&mut self) {}

        fn osc_dispatch(&mut self, _params: &[&[u8]], _bell_terminated: bool) {}

        fn csi_dispatch(
            &mut self,
            params: &Params,
            _intermediates: &[u8],
            _ignore: bool,
            c: char,
        ) {
            let params_vec = params_to_vec(params);
            self.csi_commands.push((params_vec, c));
        }

        fn esc_dispatch(&mut self, _intermediates: &[u8], _ignore: bool, _byte: u8) {}
    }

    #[test]
    fn test_parse_text() {
        let mut parser = AnsiParser::new();
        let mut performer = TestPerformer::new();

        let text = b"Hello";
        for &byte in text {
            parser.advance(&mut performer, byte);
        }

        assert_eq!(performer.printed_chars, vec!['H', 'e', 'l', 'l', 'o']);
    }

    #[test]
    fn test_parse_csi() {
        let mut parser = AnsiParser::new();
        let mut performer = TestPerformer::new();

        // CSI sequence: ESC [ 1 ; 31 m (set red foreground color)
        let sequence = b"\x1b[1;31m";
        for &byte in sequence {
            parser.advance(&mut performer, byte);
        }

        assert_eq!(performer.csi_commands.len(), 1);
        assert_eq!(performer.csi_commands[0], (vec![1, 31], 'm'));
    }
}
