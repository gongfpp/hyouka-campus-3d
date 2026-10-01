#!/usr/bin/env python3
"""Fetch only official Web/Linux x86_64 templates using ZIP HTTP ranges."""
import argparse, io, os, pathlib, struct, time, urllib.request, zipfile, zlib
VERSION = '4.6.3'
URL = f'https://github.com/godotengine/godot/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz'
WANTED = {'web_nothreads_debug.zip', 'web_nothreads_release.zip', 'linux_debug.x86_64', 'linux_release.x86_64', 'version.txt'}
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', type=pathlib.Path, default=pathlib.Path(os.environ.get('XDG_DATA_HOME', pathlib.Path.home()/'.local/share'))/'godot/export_templates'/f'{VERSION}.stable')
    args=parser.parse_args(); args.destination.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(urllib.request.Request(URL, method='HEAD'), timeout=90) as response:
        size=int(response.headers['Content-Length']); resolved=response.url
    def get(start, end):
        req=urllib.request.Request(resolved, headers={'Range':f'bytes={start}-{end}'})
        for attempt in range(3):
            try:
                with urllib.request.urlopen(req, timeout=180) as r:
                    if r.status != 206: raise RuntimeError(f'Server did not honor HTTP range: {r.status}')
                    data=r.read()
                break
            except (TimeoutError, OSError):
                if attempt == 2: raise
                time.sleep(2 ** attempt)
        if len(data) != end-start+1: raise RuntimeError('Incomplete range')
        return data
    tail=get(size-65557,size-1)
    pos=tail.rfind(b'PK\x05\x06')
    if pos < 0: raise RuntimeError('No ZIP directory')
    fields=struct.unpack_from('<4s4H2IH',tail,pos)
    directory_size, directory_offset=fields[5:7]
    directory=get(directory_offset,directory_offset+directory_size-1)
    # Standard ZipFile uses the directory and adjusts local offsets. Preserve the
    # original offset by computing each member's real archive position below.
    archive=zipfile.ZipFile(io.BytesIO(directory+tail[pos:]))
    found=set()
    for info in archive.infolist():
        name=pathlib.PurePosixPath(info.filename).name
        if name not in WANTED: continue
        found.add(name); print(f'Downloading {name} ({info.compress_size/1048576:.1f} MiB)', flush=True)
        offset=info.header_offset+directory_offset
        header=get(offset,offset+29)
        filename_len, extra_len=struct.unpack_from('<HH',header,26)
        start=offset+30+filename_len+extra_len
        compressed=get(start,start+info.compress_size-1)
        data=zlib.decompress(compressed,-15) if info.compress_type==zipfile.ZIP_DEFLATED else compressed
        if len(data)!=info.file_size or zlib.crc32(data)&0xffffffff!=info.CRC: raise RuntimeError(f'CRC mismatch: {name}')
        target=args.destination/name; target.write_bytes(data)
        if name.startswith('linux_'): target.chmod(0o755)
    if found!=WANTED: raise RuntimeError(f'Missing templates: {WANTED-found}')
    print(f'Verified templates installed in {args.destination}')
if __name__=='__main__': main()
