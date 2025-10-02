package ru.myx.distro;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;
import java.util.Map;
import java.util.zip.GZIPOutputStream;

import org.apache.commons.compress.archivers.jar.JarArchiveEntry;
import org.apache.commons.compress.archivers.jar.JarArchiveOutputStream;
import org.apache.commons.compress.archivers.tar.TarArchiveEntry;
import org.apache.commons.compress.archivers.tar.TarArchiveOutputStream;
import org.apache.commons.compress.archivers.zip.ZipArchiveEntry;
import org.apache.commons.compress.archivers.zip.ZipArchiveOutputStream;
import org.apache.commons.compress.compressors.bzip2.BZip2CompressorOutputStream;
import org.apache.commons.compress.compressors.xz.XZCompressorOutputStream;

public enum FolderPackType {
    PACK_JAR {

	@Override
	void doPack(final FolderScanCommand data, final OutputStream out) throws Exception {
	    FolderPackType.compressJar(data, out);
	}

	@Override
	String getExtension() {
	    return "jar";
	}

    }, //
    PACK_ZIP {

	@Override
	void doPack(final FolderScanCommand data, final OutputStream out) throws Exception {
	    FolderPackType.compressZip(data, out);
	}

	@Override
	String getExtension() {
	    return "zip";
	}

    }, //
    PACK_TBZ {

	@Override
	void doPack(final FolderScanCommand data, final OutputStream out) throws Exception {
	    try (final OutputStream jos = new BZip2CompressorOutputStream(out)) {
		FolderPackType.compressTar(data, jos);
	    }
	}

	@Override
	String getExtension() {
	    return "tbz";
	}

    }, //
    PACK_TGZ {

	@Override
	void doPack(final FolderScanCommand data, final OutputStream out) throws Exception {
	    try (final OutputStream jos = new GZIPOutputStream(out)) {
		FolderPackType.compressTar(data, jos);
	    }

	    /**
	     * <code>
	    if(false)
	    	try (final OutputStream jos = new GzipCompressorOutputStream(out)) {
	    		compressTar(data, jos);
	    	}
	    	</code>
	     */
	}

	@Override
	String getExtension() {
	    return "tgz";
	}

    }, //
    PACK_TXZ {

	@Override
	void doPack(final FolderScanCommand data, final OutputStream out) throws Exception {
	    try (final OutputStream jos = new XZCompressorOutputStream(out, 7)) {
		FolderPackType.compressTar(data, jos);
	    }
	}

	@Override
	String getExtension() {
	    return "txz";
	}

    }, //
    PACK_TAR {

	@Override
	void doPack(final FolderScanCommand data, final OutputStream out) throws Exception {
	    FolderPackType.compressTar(data, out);
	}

	@Override
	String getExtension() {
	    return "tar";
	}

    }, //
    ;

    static FolderPackType[] TRY = new FolderPackType[] { //
	    FolderPackType.PACK_JAR, //
	    FolderPackType.PACK_TBZ, //
	    FolderPackType.PACK_TGZ, //
	    FolderPackType.PACK_TXZ, //
    };

    public static void compressJar(final FolderScanCommand data, final OutputStream out) throws Exception {
	try (final JarArchiveOutputStream jos = new JarArchiveOutputStream(out)) {
	    jos.setLevel(9);

	    for (final Map.Entry<Path, FolderScanCommand.ScanFileRecord> file : data.knownFiles.entrySet()) {
		final Path key = file.getKey();
		final FolderScanCommand.ScanFileRecord item = file.getValue();

		try {
		    final JarArchiveEntry entry = new JarArchiveEntry(key.toString());
		    entry.setSize(item.size);
		    entry.setLastModifiedTime(FileTime.fromMillis(item.modified));
		    jos.putArchiveEntry(entry);
		    jos.write(item.bytes());
		    jos.closeArchiveEntry();
		} catch (final IOException e) {
		    throw new RuntimeException(e);
		}
	    }
	}
    }

    public static void compressZip(final FolderScanCommand data, final OutputStream out) throws Exception {
	try (final ZipArchiveOutputStream jos = new ZipArchiveOutputStream(out)) {
	    jos.setLevel(9);

	    for (final Map.Entry<Path, FolderScanCommand.ScanFileRecord> file : data.knownFiles.entrySet()) {
		final Path key = file.getKey();
		final FolderScanCommand.ScanFileRecord item = file.getValue();

		try {
		    final ZipArchiveEntry entry = new ZipArchiveEntry(key.toString());
		    entry.setSize(item.size);
		    entry.setLastModifiedTime(FileTime.fromMillis(item.modified));
		    jos.putArchiveEntry(entry);
		    jos.write(item.bytes());
		    jos.closeArchiveEntry();
		} catch (final IOException e) {
		    throw new RuntimeException(e);
		}
	    }
	}
    }

    public static void compressTar(final FolderScanCommand data, final OutputStream jos) throws Exception {
	try (final TarArchiveOutputStream tos = new TarArchiveOutputStream(jos)) {
	    tos.setLongFileMode(TarArchiveOutputStream.LONGFILE_POSIX);
	    tos.setBigNumberMode(TarArchiveOutputStream.BIGNUMBER_POSIX);
	    tos.setAddPaxHeadersForNonAsciiNames(false);

	    for (final Map.Entry<Path, FolderScanCommand.ScanFileRecord> file : data.knownFiles.entrySet()) {
		final Path key = file.getKey();
		final FolderScanCommand.ScanFileRecord item = file.getValue();

		try {
		    final TarArchiveEntry entry = new TarArchiveEntry(key.toString());
		    entry.setSize(item.size);
		    entry.setModTime(item.modified);
		    tos.putArchiveEntry(entry);
		    tos.write(item.bytes());
		    tos.closeArchiveEntry();
		} catch (final IOException e) {
		    throw new RuntimeException(e);
		}
	    }
	}
    }

    abstract void doPack(final FolderScanCommand data, final OutputStream out) throws Exception;

    abstract String getExtension();
}
