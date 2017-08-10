//  HTMLEncoding.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLEncoding.h"

/**
 * Returns the name of an encoding given by a label, as specified in the WHATWG Encoding standard, or nil if the label has no associated name.
 *
 * For more information, see https://encoding.spec.whatwg.org/#names-and-labels
 */
static NSString * NamedEncodingForLabel(NSString *label);

/**
 * Returns the string encoding given by a name from the WHATWG Encoding Standard, or the result of InvalidStringEncoding() if there is no known encoding given by name.
 */
static NSStringEncoding StringEncodingForName(NSString *name);

HTMLStringEncoding DeterminedStringEncodingForData(NSData *data, NSString *contentType)
{
    unsigned char buffer[3] = {0};
    [data getBytes:buffer length:MIN(data.length, 3U)];
    if (buffer[0] == 0xFE && buffer[1] == 0xFF) {
        return (HTMLStringEncoding){
            .encoding = NSUTF16BigEndianStringEncoding,
            .confidence = Certain
        };
    } else if (buffer[0] == 0xFF && buffer[1] == 0xFE) {
        return (HTMLStringEncoding){
            .encoding = NSUTF16LittleEndianStringEncoding,
            .confidence = Certain
        };
    } else if (buffer[0] == 0xEF && buffer[1] == 0xBB && buffer[2] == 0xBF) {
        return (HTMLStringEncoding){
            .encoding = NSUTF8StringEncoding,
            .confidence = Certain
        };
    }
    
    if (contentType) {
        // http://tools.ietf.org/html/rfc7231#section-3.1.1.1
        NSScanner *scanner = [NSScanner scannerWithString:contentType];
        [scanner scanUpToString:@"charset=" intoString:nil];
        if ([scanner scanString:@"charset=" intoString:nil]) {
            [scanner scanString:@"\"" intoString:nil];
            NSString *encodingLabel;
            if ([scanner scanUpToString:@"\"" intoString:&encodingLabel]) {
                NSStringEncoding encoding = StringEncodingForLabel(encodingLabel);
                if (encoding != InvalidStringEncoding()) {
                    return (HTMLStringEncoding){
                        .encoding = encoding,
                        .confidence = Certain
                    };
                }
            }
        }
    }
    
    // TODO Prescan?
    
    // TODO There's a table down in step 9 of https://html.spec.whatwg.org/multipage/syntax.html#documentEncoding that describes default encodings based on the current locale. Maybe implement that.
    
    // win1252 actually has some invalid characters in it, so it's not a guarantee that it'll work, so try it first.
    if ([[NSString alloc] initWithData:data encoding:NSWindowsCP1252StringEncoding]) {
        return (HTMLStringEncoding){
            .encoding = NSWindowsCP1252StringEncoding,
            .confidence = Tentative
        };
    } else {
        // iso8869-1 is the closest sensible default to win1252 that always decodes.
        return (HTMLStringEncoding){
            .encoding = NSISOLatin1StringEncoding,
            .confidence = Tentative
        };
    }
}

typedef struct {
    __unsafe_unretained NSString *label;
    __unsafe_unretained NSString *name;
} EncodingLabelMap;

// This array is generated by the Encoding Labeler utility. Please don't make adjustments here.
static const EncodingLabelMap EncodingLabels[] = {
    { @"866", @"ibm866" },
    { @"ansi_x3.4-1968", @"windows-1252" },
    { @"arabic", @"iso-8859-6" },
    { @"ascii", @"windows-1252" },
    { @"asmo-708", @"iso-8859-6" },
    { @"big5", @"big5" },
    { @"big5-hkscs", @"big5" },
    { @"chinese", @"gbk" },
    { @"cn-big5", @"big5" },
    { @"cp1250", @"windows-1250" },
    { @"cp1251", @"windows-1251" },
    { @"cp1252", @"windows-1252" },
    { @"cp1253", @"windows-1253" },
    { @"cp1254", @"windows-1254" },
    { @"cp1255", @"windows-1255" },
    { @"cp1256", @"windows-1256" },
    { @"cp1257", @"windows-1257" },
    { @"cp1258", @"windows-1258" },
    { @"cp819", @"windows-1252" },
    { @"cp866", @"ibm866" },
    { @"csbig5", @"big5" },
    { @"cseuckr", @"euc-kr" },
    { @"cseucpkdfmtjapanese", @"euc-jp" },
    { @"csgb2312", @"gbk" },
    { @"csibm866", @"ibm866" },
    { @"csiso2022jp", @"iso-2022-jp" },
    { @"csiso2022kr", @"replacement" },
    { @"csiso58gb231280", @"gbk" },
    { @"csiso88596e", @"iso-8859-6" },
    { @"csiso88596i", @"iso-8859-6" },
    { @"csiso88598e", @"iso-8859-8" },
    { @"csiso88598i", @"iso-8859-8-i" },
    { @"csisolatin1", @"windows-1252" },
    { @"csisolatin2", @"iso-8859-2" },
    { @"csisolatin3", @"iso-8859-3" },
    { @"csisolatin4", @"iso-8859-4" },
    { @"csisolatin5", @"windows-1254" },
    { @"csisolatin6", @"iso-8859-10" },
    { @"csisolatin9", @"iso-8859-15" },
    { @"csisolatinarabic", @"iso-8859-6" },
    { @"csisolatincyrillic", @"iso-8859-5" },
    { @"csisolatingreek", @"iso-8859-7" },
    { @"csisolatinhebrew", @"iso-8859-8" },
    { @"cskoi8r", @"koi8-r" },
    { @"csksc56011987", @"euc-kr" },
    { @"csmacintosh", @"macintosh" },
    { @"csshiftjis", @"shift_jis" },
    { @"cyrillic", @"iso-8859-5" },
    { @"dos-874", @"windows-874" },
    { @"ecma-114", @"iso-8859-6" },
    { @"ecma-118", @"iso-8859-7" },
    { @"elot_928", @"iso-8859-7" },
    { @"euc-jp", @"euc-jp" },
    { @"euc-kr", @"euc-kr" },
    { @"gb18030", @"gb18030" },
    { @"gb2312", @"gbk" },
    { @"gb_2312", @"gbk" },
    { @"gb_2312-80", @"gbk" },
    { @"gbk", @"gbk" },
    { @"greek", @"iso-8859-7" },
    { @"greek8", @"iso-8859-7" },
    { @"hebrew", @"iso-8859-8" },
    { @"hz-gb-2312", @"replacement" },
    { @"ibm819", @"windows-1252" },
    { @"ibm866", @"ibm866" },
    { @"iso-2022-cn", @"replacement" },
    { @"iso-2022-cn-ext", @"replacement" },
    { @"iso-2022-jp", @"iso-2022-jp" },
    { @"iso-2022-kr", @"replacement" },
    { @"iso-8859-1", @"windows-1252" },
    { @"iso-8859-10", @"iso-8859-10" },
    { @"iso-8859-11", @"windows-874" },
    { @"iso-8859-13", @"iso-8859-13" },
    { @"iso-8859-14", @"iso-8859-14" },
    { @"iso-8859-15", @"iso-8859-15" },
    { @"iso-8859-16", @"iso-8859-16" },
    { @"iso-8859-2", @"iso-8859-2" },
    { @"iso-8859-3", @"iso-8859-3" },
    { @"iso-8859-4", @"iso-8859-4" },
    { @"iso-8859-5", @"iso-8859-5" },
    { @"iso-8859-6", @"iso-8859-6" },
    { @"iso-8859-6-e", @"iso-8859-6" },
    { @"iso-8859-6-i", @"iso-8859-6" },
    { @"iso-8859-7", @"iso-8859-7" },
    { @"iso-8859-8", @"iso-8859-8" },
    { @"iso-8859-8-e", @"iso-8859-8" },
    { @"iso-8859-8-i", @"iso-8859-8-i" },
    { @"iso-8859-9", @"windows-1254" },
    { @"iso-ir-100", @"windows-1252" },
    { @"iso-ir-101", @"iso-8859-2" },
    { @"iso-ir-109", @"iso-8859-3" },
    { @"iso-ir-110", @"iso-8859-4" },
    { @"iso-ir-126", @"iso-8859-7" },
    { @"iso-ir-127", @"iso-8859-6" },
    { @"iso-ir-138", @"iso-8859-8" },
    { @"iso-ir-144", @"iso-8859-5" },
    { @"iso-ir-148", @"windows-1254" },
    { @"iso-ir-149", @"euc-kr" },
    { @"iso-ir-157", @"iso-8859-10" },
    { @"iso-ir-58", @"gbk" },
    { @"iso8859-1", @"windows-1252" },
    { @"iso8859-10", @"iso-8859-10" },
    { @"iso8859-11", @"windows-874" },
    { @"iso8859-13", @"iso-8859-13" },
    { @"iso8859-14", @"iso-8859-14" },
    { @"iso8859-15", @"iso-8859-15" },
    { @"iso8859-2", @"iso-8859-2" },
    { @"iso8859-3", @"iso-8859-3" },
    { @"iso8859-4", @"iso-8859-4" },
    { @"iso8859-5", @"iso-8859-5" },
    { @"iso8859-6", @"iso-8859-6" },
    { @"iso8859-7", @"iso-8859-7" },
    { @"iso8859-8", @"iso-8859-8" },
    { @"iso8859-9", @"windows-1254" },
    { @"iso88591", @"windows-1252" },
    { @"iso885910", @"iso-8859-10" },
    { @"iso885911", @"windows-874" },
    { @"iso885913", @"iso-8859-13" },
    { @"iso885914", @"iso-8859-14" },
    { @"iso885915", @"iso-8859-15" },
    { @"iso88592", @"iso-8859-2" },
    { @"iso88593", @"iso-8859-3" },
    { @"iso88594", @"iso-8859-4" },
    { @"iso88595", @"iso-8859-5" },
    { @"iso88596", @"iso-8859-6" },
    { @"iso88597", @"iso-8859-7" },
    { @"iso88598", @"iso-8859-8" },
    { @"iso88599", @"windows-1254" },
    { @"iso_8859-1", @"windows-1252" },
    { @"iso_8859-15", @"iso-8859-15" },
    { @"iso_8859-1:1987", @"windows-1252" },
    { @"iso_8859-2", @"iso-8859-2" },
    { @"iso_8859-2:1987", @"iso-8859-2" },
    { @"iso_8859-3", @"iso-8859-3" },
    { @"iso_8859-3:1988", @"iso-8859-3" },
    { @"iso_8859-4", @"iso-8859-4" },
    { @"iso_8859-4:1988", @"iso-8859-4" },
    { @"iso_8859-5", @"iso-8859-5" },
    { @"iso_8859-5:1988", @"iso-8859-5" },
    { @"iso_8859-6", @"iso-8859-6" },
    { @"iso_8859-6:1987", @"iso-8859-6" },
    { @"iso_8859-7", @"iso-8859-7" },
    { @"iso_8859-7:1987", @"iso-8859-7" },
    { @"iso_8859-8", @"iso-8859-8" },
    { @"iso_8859-8:1988", @"iso-8859-8" },
    { @"iso_8859-9", @"windows-1254" },
    { @"iso_8859-9:1989", @"windows-1254" },
    { @"koi", @"koi8-r" },
    { @"koi8", @"koi8-r" },
    { @"koi8-r", @"koi8-r" },
    { @"koi8-u", @"koi8-u" },
    { @"koi8_r", @"koi8-r" },
    { @"korean", @"euc-kr" },
    { @"ks_c_5601-1987", @"euc-kr" },
    { @"ks_c_5601-1989", @"euc-kr" },
    { @"ksc5601", @"euc-kr" },
    { @"ksc_5601", @"euc-kr" },
    { @"l1", @"windows-1252" },
    { @"l2", @"iso-8859-2" },
    { @"l3", @"iso-8859-3" },
    { @"l4", @"iso-8859-4" },
    { @"l5", @"windows-1254" },
    { @"l6", @"iso-8859-10" },
    { @"l9", @"iso-8859-15" },
    { @"latin1", @"windows-1252" },
    { @"latin2", @"iso-8859-2" },
    { @"latin3", @"iso-8859-3" },
    { @"latin4", @"iso-8859-4" },
    { @"latin5", @"windows-1254" },
    { @"latin6", @"iso-8859-10" },
    { @"logical", @"iso-8859-8-i" },
    { @"mac", @"macintosh" },
    { @"macintosh", @"macintosh" },
    { @"ms_kanji", @"shift_jis" },
    { @"shift-jis", @"shift_jis" },
    { @"shift_jis", @"shift_jis" },
    { @"sjis", @"shift_jis" },
    { @"sun_eu_greek", @"iso-8859-7" },
    { @"tis-620", @"windows-874" },
    { @"unicode-1-1-utf-8", @"utf-8" },
    { @"us-ascii", @"windows-1252" },
    { @"utf-16", @"utf-16le" },
    { @"utf-16be", @"utf-16be" },
    { @"utf-16le", @"utf-16le" },
    { @"utf-8", @"utf-8" },
    { @"utf8", @"utf-8" },
    { @"visual", @"iso-8859-8" },
    { @"windows-1250", @"windows-1250" },
    { @"windows-1251", @"windows-1251" },
    { @"windows-1252", @"windows-1252" },
    { @"windows-1253", @"windows-1253" },
    { @"windows-1254", @"windows-1254" },
    { @"windows-1255", @"windows-1255" },
    { @"windows-1256", @"windows-1256" },
    { @"windows-1257", @"windows-1257" },
    { @"windows-1258", @"windows-1258" },
    { @"windows-31j", @"shift_jis" },
    { @"windows-874", @"windows-874" },
    { @"windows-949", @"euc-kr" },
    { @"x-cp1250", @"windows-1250" },
    { @"x-cp1251", @"windows-1251" },
    { @"x-cp1252", @"windows-1252" },
    { @"x-cp1253", @"windows-1253" },
    { @"x-cp1254", @"windows-1254" },
    { @"x-cp1255", @"windows-1255" },
    { @"x-cp1256", @"windows-1256" },
    { @"x-cp1257", @"windows-1257" },
    { @"x-cp1258", @"windows-1258" },
    { @"x-euc-jp", @"euc-jp" },
    { @"x-gbk", @"gbk" },
    { @"x-mac-cyrillic", @"x-mac-cyrillic" },
    { @"x-mac-roman", @"macintosh" },
    { @"x-mac-ukrainian", @"x-mac-cyrillic" },
    { @"x-sjis", @"shift_jis" },
    { @"x-user-defined", @"x-user-defined" },
    { @"x-x-big5", @"big5" },
};

static int (^EncodingLabelComparator)(const void *, const void *) = ^int(const void *voidKey, const void *voidItem) {
    const NSString *key = (__bridge const NSString *)voidKey;
    const EncodingLabelMap *item = voidItem;
    return [key caseInsensitiveCompare:item->label];
};

static NSString * NamedEncodingForLabel(NSString *label)
{
    EncodingLabelMap *match = bsearch_b((__bridge const void *)label, EncodingLabels, sizeof(EncodingLabels) / sizeof(EncodingLabels[0]), sizeof(EncodingLabels[0]), EncodingLabelComparator);
    if (match) {
        return match->name;
    } else {
        return nil;
    }
}

typedef struct {
    __unsafe_unretained NSString *name;
    CFStringEncoding encoding;
} NameCFEncodingMap;

// This array is generated by the Encoding Labeler utility. Please make adjustments over there, not over here.
static const NameCFEncodingMap StringEncodings[] = {
    { @"big5", kCFStringEncodingBig5 },
    { @"euc-jp", kCFStringEncodingEUC_JP },
    { @"euc-kr", kCFStringEncodingEUC_KR },
    { @"gb18030", kCFStringEncodingGB_18030_2000 },
    { @"gbk", kCFStringEncodingGBK_95 },
    { @"ibm866", kCFStringEncodingDOSRussian },
    { @"iso-2022-jp", kCFStringEncodingISO_2022_JP },
    { @"iso-8859-10", kCFStringEncodingISOLatin6 },
    { @"iso-8859-13", kCFStringEncodingISOLatin7 },
    { @"iso-8859-14", kCFStringEncodingISOLatin8 },
    { @"iso-8859-15", kCFStringEncodingISOLatin9 },
    { @"iso-8859-16", kCFStringEncodingISOLatin10 },
    { @"iso-8859-2", kCFStringEncodingISOLatin2 },
    { @"iso-8859-3", kCFStringEncodingISOLatin3 },
    { @"iso-8859-4", kCFStringEncodingISOLatin4 },
    { @"iso-8859-5", kCFStringEncodingISOLatinCyrillic },
    { @"iso-8859-6", kCFStringEncodingISOLatinArabic },
    { @"iso-8859-7", kCFStringEncodingISOLatinGreek },
    { @"iso-8859-8", kCFStringEncodingISOLatinHebrew },
    { @"iso-8859-8-i", kCFStringEncodingISOLatinHebrew },
    { @"koi8-r", kCFStringEncodingKOI8_R },
    { @"koi8-u", kCFStringEncodingKOI8_U },
    { @"macintosh", kCFStringEncodingMacRoman },
    { @"replacement", kCFStringEncodingInvalidId },
    { @"shift_jis", kCFStringEncodingShiftJIS },
    { @"utf-16be", kCFStringEncodingUTF16BE },
    { @"utf-16le", kCFStringEncodingUTF16LE },
    { @"utf-8", kCFStringEncodingUTF8 },
    { @"windows-1250", kCFStringEncodingWindowsLatin2 },
    { @"windows-1251", kCFStringEncodingWindowsCyrillic },
    { @"windows-1252", kCFStringEncodingWindowsLatin1 },
    { @"windows-1253", kCFStringEncodingWindowsGreek },
    { @"windows-1254", kCFStringEncodingWindowsLatin5 },
    { @"windows-1255", kCFStringEncodingWindowsHebrew },
    { @"windows-1256", kCFStringEncodingWindowsArabic },
    { @"windows-1257", kCFStringEncodingWindowsBalticRim },
    { @"windows-1258", kCFStringEncodingWindowsVietnamese },
    { @"windows-874", kCFStringEncodingDOSThai },
    { @"x-mac-cyrillic", kCFStringEncodingMacCyrillic },
    // SPEC: The HTML standard unilaterally changes x-user-defined to windows-1252, so let's just define it so.
    { @"x-user-defined", kCFStringEncodingWindowsLatin1 },
};

static int (^NameCFEncodingComparator)(const void *, const void *) = ^int(const void *voidKey, const void *voidItem) {
    const NSString *key = (__bridge const NSString *)voidKey;
    const NameCFEncodingMap *item = voidItem;
    return [key caseInsensitiveCompare:item->name];
};

static NSStringEncoding StringEncodingForName(NSString *name)
{
    NameCFEncodingMap *match = bsearch_b((__bridge const void *)name, StringEncodings, sizeof(StringEncodings) / sizeof(StringEncodings[0]), sizeof(StringEncodings[0]), NameCFEncodingComparator);
    if (match) {
        return CFStringConvertEncodingToNSStringEncoding(match->encoding);
    } else {
        return InvalidStringEncoding();
    }
}

NSStringEncoding InvalidStringEncoding(void)
{
    return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingInvalidId);
}

NSStringEncoding StringEncodingForLabel(NSString *untrimmedLabel)
{
    NSString *label = [untrimmedLabel stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *name = NamedEncodingForLabel(label);
    if (name) {
        return StringEncodingForName(name);
    } else {
        return InvalidStringEncoding();
    }
}

BOOL IsASCIICompatibleEncoding(NSStringEncoding nsencoding)
{
    CFStringEncoding encoding = CFStringConvertNSStringEncodingToEncoding(nsencoding);
    switch (encoding) {
        // TODO This is a bespoke list, as I couldn't find a handy list from WHATWG or elsewhere. I guess we could code up their definition of "ASCII-compatible" and run through the list of known string encodings?
        case kCFStringEncodingUTF7:
        case kCFStringEncodingUTF16:
        case kCFStringEncodingUTF16BE:
        case kCFStringEncodingUTF16LE:
        case kCFStringEncodingHZ_GB_2312:
        case kCFStringEncodingUTF7_IMAP:
            return NO;
        default:
            return YES;
    }
}

BOOL IsUTF16Encoding(NSStringEncoding encoding)
{
    switch (encoding) {
        case NSUTF16BigEndianStringEncoding:
        case NSUTF16LittleEndianStringEncoding:
            return YES;
        default:
            return NO;
    }
}
