import QRCode from "qrcode";

/**
 * QR code as an SVG string. Colours come from CSS (see QrCode): the library's
 * default fills are overridden with the ink and surface tokens.
 */
export async function qrSvg(value: string): Promise<string> {
  return QRCode.toString(value, {
    type: "svg",
    errorCorrectionLevel: "M",
    margin: 2,
  });
}
