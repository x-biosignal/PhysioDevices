#!/usr/bin/env python3
"""Generate inst/extdata/biopac_sample.acq: a minimal AcqKnowledge (.acq) file
that bioread reads. Two channels at different rates (ECG 1000 Hz divider 1,
Resp 500 Hz divider 2), float64 samples, and one event marker.

The byte layout is packed field-by-field from bioread's own header StructDicts,
so it matches whatever version we target (V_390, little-endian)."""
import struct
import re
import bioread.headers as bh
import bioread.file_revisions as rev

BOC = "<"
V = rev.V_390


def field_defaults(header):
    """Ordered (name, fmt) -> flattened default value list for struct.pack."""
    info = header.struct_dict.struct_info
    fields = []
    for entry in info:
        name, fmt = entry[0], entry[1]
        m = re.match(r"(\d*)([a-zA-Z])", fmt)
        count = int(m.group(1)) if m.group(1) else 1
        typ = m.group(2)
        fields.append((name, count, typ))
    return fields


def pack_header(header, overrides):
    fields = field_defaults(header)
    values = []
    for name, count, typ in fields:
        if typ == "s":
            v = overrides.get(name, b"")
            if isinstance(v, str):
                v = v.encode("latin1")
            values.append(v[:count].ljust(count, b"\x00"))
        else:
            v = overrides.get(name, 0)
            if count == 1:
                values.append(v)
            else:
                seq = v if isinstance(v, (list, tuple)) else [v] * count
                seq = list(seq)[:count] + [0] * (count - len(seq))
                values.extend(seq)
    fmt = BOC + header.struct_dict.format_string.lstrip("<>=")
    return struct.pack(fmt, *values)


gh = bh.GraphHeader(V, BOC)
gh_len = gh.struct_dict.len_bytes
ch = bh.ChannelHeader(V, BOC)
ch_len = ch.struct_dict.len_bytes
fh = bh.ForeignHeader(V, BOC)
cdt = bh.ChannelDTypeHeader(V, BOC)

parts = []

# Graph header: 2 channels, 1 ms base sample time (1000 Hz base), uncompressed.
parts.append(pack_header(gh, {
    "nItemHeaderLen": gh_len, "lVersion": V, "lExtItemHeaderLen": gh_len,
    "nChannels": 2, "dSampleTime": 1.0, "bCompressed": 0}))

# Channel headers (label, unit, point count, sample divider, unit scale 1:1).
chan_specs = [
    dict(nNum=0, szCommentText=b"ECG",  szUnitsText=b"mV", lBufLength=4,
         nVarSampleDivider=1),
    dict(nNum=1, szCommentText=b"Resp", szUnitsText=b"L",  lBufLength=2,
         nVarSampleDivider=2)]
for spec in chan_specs:
    ov = dict(spec)
    ov.update({"lChanHeaderLen": ch_len, "dAmplScale": 1.0, "dAmplOffset": 0.0,
               "dVoltScale": 1.0, "dVoltOffset": 0.0})
    parts.append(pack_header(ch, ov))

# Foreign header (no extra foreign bytes).
parts.append(pack_header(fh, {"nLength": fh.struct_dict.len_bytes, "nType": 0}))

# Channel dtype headers: float64 (code 1), 8 bytes each.
for _ in range(2):
    parts.append(pack_header(cdt, {"nSize": 8, "nType": 1}))

# Interleaved data for dividers [1, 2] over 4 base samples.
# sample pattern per LCM(=2) cycle: [ch0, ch1, ch0]; two cycles -> [0,1,0,0,1,0]
ch0 = [1.0, 2.0, 3.0, 4.0]
ch1 = [10.0, 20.0]
order = [(0, 0), (1, 0), (0, 1), (0, 2), (1, 1), (0, 3)]
for cidx, sidx in order:
    val = ch0[sidx] if cidx == 0 else ch1[sidx]
    parts.append(struct.pack(BOC + "d", val))

# One marker at base sample index 2 ("stim").
mh = bh.V2MarkerHeader(V, BOC)
mih = bh.V2MarkerItemHeader(V, BOC)
text = b"stim\x00"
parts.append(pack_header(mh, {"lLength": mh.struct_dict.len_bytes, "lMarkers": 1}))
parts.append(pack_header(mih, {"lSample": 2, "nTextLength": len(text)}))
parts.append(text)

out = "inst/extdata/biopac_sample.acq"
with open(out, "wb") as f:
    f.write(b"".join(parts))
print("wrote", out, sum(len(p) for p in parts), "bytes")
