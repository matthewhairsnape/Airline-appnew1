# IATA Barcode and QR Code Handling Guide

## Overview

This guide explains how to handle IATA (International Air Transport Association) data when scanning barcodes and QR codes in your airline app. The scanner now supports multiple IATA formats with robust validation and error handling.

## Supported IATA Formats

### 1. BCBP (Bar Coded Boarding Pass) Format
**Format Code:** M1 or M2
**Example:** `M1HAIRSNAPE/MATTHEWM          CTABEGJU 439  244 12A 0209  00`

**Structure:**
- `M1/M2` - Format identifier
- Next 20 chars - Passenger name (padded with spaces)
- Next 3 chars - Origin airport code (e.g., CTA)
- Next 3 chars - Destination airport code (e.g., BEG)
- Next 2 chars - Operating carrier code (e.g., JU)
- Next variable - Flight number (e.g., 439)
- Next 3 chars - Julian date (e.g., 244)
- Next 3 chars - Seat number (e.g., 12A)
- Rest - Additional data

### 2. Legacy IATA Format
**Example:** `TEST123456 JFKAA100 100 001Y`

**Structure:**
- PNR (5-7 alphanumeric characters)
- Space separator
- Route (8 characters: 3 airport + 2 carrier + 3 flight padded)
- Space separator
- Flight number (4 digits)
- Space separator
- Julian date + Class (3 digits + 1 letter)

### 3. QR Code Format
**Supports multiple patterns:**
- JSON-like structure: `{"pnr":"TEST123","carrier":"AA","flightNumber":"100"}`
- Space-separated: `TEST123 AA 100 JFK LAX`
- Pipe-separated: `TEST123|AA|100|JFK|LAX`

## Implementation Features

### Automatic Format Detection
The scanner automatically detects the IATA format type:
```dart
enum IataFormat {
  BCBP,      // Bar Coded Boarding Pass (M1/M2)
  Legacy,    // Legacy IATA format
  QRCode,    // QR Code with IATA data
  Unknown    // Unknown format
}
```

### Data Validation
Comprehensive validation for all IATA data:
- **PNR Validation:** 5-7 alphanumeric characters
- **Airport Code Validation:** Exactly 3 uppercase letters
- **Carrier Code Validation:** 2-3 uppercase letters
- **Flight Number Validation:** 3-4 digits

### Error Handling
Specific error messages for different failure scenarios:
- Invalid barcode format
- Invalid PNR format
- Invalid carrier code
- Invalid airport code
- Unsupported format
- QR code parsing failure

## Usage Examples

### Scanning BCBP Format
```dart
// Input: M1HAIRSNAPE/MATTHEWM          CTABEGJU 439  244 12A 0209  00
// Output:
// - PNR: CTABEG (generated from carrier + flight + airport)
// - Carrier: JU
// - Flight: 439
// - Departure: CTA
// - Arrival: BEG
// - Seat: 12A
// - Date: Calculated from Julian day 244
```

### Scanning Legacy IATA Format
```dart
// Input: TEST123456 JFKAA100 100 001Y
// Output:
// - PNR: TEST123456
// - Carrier: AA
// - Flight: 100
// - Departure: JFK
// - Class: Economy (Y)
// - Date: January 1st (Julian day 001)
```

### Scanning QR Code Format
```dart
// Input: {"pnr":"TEST123","carrier":"AA","flightNumber":"100","departureAirport":"JFK","arrivalAirport":"LAX","seat":"12A","class":"Y"}
// Output:
// - PNR: TEST123
// - Carrier: AA
// - Flight: 100
// - Departure: JFK
// - Arrival: LAX
// - Seat: 12A
// - Class: Economy
```

## Best Practices

### 1. Format Detection
Always use the automatic format detection before parsing:
```dart
final formatType = _detectIataFormat(rawValue);
```

### 2. Validation
Validate all extracted data before processing:
```dart
if (!_isValidPnr(pnr) || !_isValidIataCarrierCode(carrier)) {
  // Handle validation error
}
```

### 3. Error Handling
Provide specific error messages for different failure types:
```dart
CustomSnackBar.error(context, 'Invalid PNR format. Please scan a valid boarding pass.');
```

### 4. Debugging
Use comprehensive logging for troubleshooting:
```dart
debugPrint("🔍 Detected IATA format: $formatType");
debugPrint("✅ Parsed BCBP boarding pass:");
debugPrint("  Departure: $departureAirport");
```

## Common Issues and Solutions

### Issue: "Unknown IATA format"
**Solution:** Check if the barcode contains valid IATA patterns. Ensure it's not a generic QR code without flight data.

### Issue: "Invalid PNR format"
**Solution:** PNR must be 5-7 alphanumeric characters. Check for extra spaces or special characters.

### Issue: "Invalid carrier code"
**Solution:** Carrier codes must be 2-3 uppercase letters (e.g., AA, DL, BA).

### Issue: "Invalid airport code"
**Solution:** Airport codes must be exactly 3 uppercase letters (e.g., JFK, LAX, LHR).

## Testing

Use the provided test barcode generator (`test_barcode_generator.html`) to create test QR codes with different IATA formats for testing your scanner implementation.

## Future Enhancements

Consider adding support for:
- Additional IATA barcode formats
- Checksum validation for data integrity
- Enhanced QR code pattern recognition
- Support for multi-segment boarding passes
- Integration with airline-specific barcode formats

## References

- [IATA BCBP Implementation Guide](https://www.iata.org/en/programs/passenger/common-use/)
- [IATA Digital Manuals](https://www.iata.org/en/publications/digital/)
- [IATA 2 of 5 Barcode Specification](https://documentation.activepdf.com/Toolkit/Toolkit_API/Content/4_b_barcode_appendix/Code_2_of_5_IATA.html)
