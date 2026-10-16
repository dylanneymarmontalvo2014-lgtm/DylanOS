// Runs every file operation inside a QTemporaryDir; nothing outside it is touched.
#include "services/FileOperations.h"
#include "services/Formatters.h"

#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QtTest>

#include <atomic>

namespace {
void write(const QString &path, const QByteArray &data)
{
    QFile f(path);
    QVERIFY2(f.open(QIODevice::WriteOnly), qPrintable(path));
    f.write(data);
}
} // namespace

class TestFileOperations : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        QVERIFY(m_tmp.isValid());
        // Keep the freedesktop trash inside the temp dir so nothing real is trashed.
        qputenv("XDG_DATA_HOME", (m_tmp.path() + "/xdg").toUtf8());
        QDir().mkpath(m_tmp.path() + "/xdg");
    }

    void validNames()
    {
        QVERIFY(FileOperations::isValidName(QStringLiteral("Informe año 2025 ñ.docx")));
        QVERIFY(FileOperations::isValidName(QStringLiteral(".oculto")));
        QVERIFY(!FileOperations::isValidName(QString()));
        QVERIFY(!FileOperations::isValidName(QStringLiteral("  ")));
        QVERIFY(!FileOperations::isValidName(QStringLiteral("a/b")));
        QVERIFY(!FileOperations::isValidName(QStringLiteral("..")));
    }

    void uniqueNames()
    {
        const QString d = m_tmp.path();
        write(d + "/a b.txt", "x");
        QCOMPARE(FileOperations::uniqueName(d, "a b.txt"), QString("a b (copia).txt"));
        write(d + "/a b (copia).txt", "x");
        QCOMPARE(FileOperations::uniqueName(d, "a b.txt"), QString("a b (copia 2).txt"));
        write(d + "/.rc", "x");
        QCOMPARE(FileOperations::uniqueName(d, ".rc"), QString(".rc (copia)"));
    }

    void createAndRename()
    {
        const QString d = m_tmp.path();
        auto r = FileOperations::createFolder(d, "Nueva carpeta ✓");
        QVERIFY(r.ok);
        QVERIFY(QFileInfo(d + "/Nueva carpeta ✓").isDir());
        QVERIFY(!FileOperations::createFolder(d, "Nueva carpeta ✓").ok); // already exists
        r = FileOperations::rename(d + "/Nueva carpeta ✓", "Renombrada");
        QVERIFY(r.ok);
        QVERIFY(QFileInfo(d + "/Renombrada").isDir());
        QVERIFY(!FileOperations::rename(d + "/Renombrada", "x/y").ok);
    }

    void copyTreeWithProgress()
    {
        const QString d = m_tmp.path() + "/copy";
        QDir().mkpath(d + "/src/sub dir");
        QDir().mkpath(d + "/dst");
        write(d + "/src/a.bin", QByteArray(3 * 1024 * 1024 + 17, 'a'));
        write(d + "/src/sub dir/b.txt", "hola");
        qint64 lastDone = 0, lastTotal = 0;
        auto r = FileOperations::transfer({d + "/src"}, d + "/dst", false,
                                          [&](qint64 done, qint64 total) { lastDone = done; lastTotal = total; });
        QVERIFY2(r.ok, qPrintable(r.error));
        QCOMPARE(QFileInfo(d + "/dst/src/a.bin").size(), qint64(3 * 1024 * 1024 + 17));
        QVERIFY(QFileInfo(d + "/dst/src/sub dir/b.txt").exists());
        QVERIFY(QFileInfo(d + "/src/a.bin").exists()); // copy keeps the source
        QCOMPARE(lastDone, lastTotal);
        // Copying into the same folder creates "(copia)".
        r = FileOperations::transfer({d + "/src/sub dir/b.txt"}, d + "/src/sub dir", false);
        QVERIFY(r.ok);
        QVERIFY(QFileInfo(d + "/src/sub dir/b (copia).txt").exists());
    }

    void moveRemovesSource()
    {
        const QString d = m_tmp.path() + "/move";
        QDir().mkpath(d + "/from");
        QDir().mkpath(d + "/to");
        write(d + "/from/f.txt", "datos");
        auto r = FileOperations::transfer({d + "/from/f.txt"}, d + "/to", true);
        QVERIFY2(r.ok, qPrintable(r.error));
        QVERIFY(!QFileInfo(d + "/from/f.txt").exists());
        QVERIFY(QFileInfo(d + "/to/f.txt").exists());
    }

    void rejectsCopyIntoItself()
    {
        const QString d = m_tmp.path() + "/self";
        QDir().mkpath(d + "/a/b");
        const auto r = FileOperations::transfer({d + "/a"}, d + "/a/b", false);
        QVERIFY(!r.ok);
        QVERIFY(!QFileInfo(d + "/a/b/a").exists());
    }

    void cancelRemovesPartialCopy()
    {
        const QString d = m_tmp.path() + "/cancel";
        QDir().mkpath(d + "/dst");
        write(d + "/big.bin", QByteArray(4 * 1024 * 1024, 'z'));
        std::atomic_bool cancel{false};
        auto r = FileOperations::transfer({d + "/big.bin"}, d + "/dst", false,
                                          [&](qint64, qint64) { cancel = true; }, &cancel);
        QVERIFY(r.cancelled);
        QVERIFY(!QFileInfo(d + "/dst/big.bin").exists());
    }

    void protectedPaths()
    {
        QVERIFY(FileOperations::isProtectedPath("/"));
        QVERIFY(FileOperations::isProtectedPath("/etc"));
        QVERIFY(FileOperations::isProtectedPath(QDir::homePath()));
        QVERIFY(!FileOperations::isProtectedPath(m_tmp.path() + "/copy/src"));
        QVERIFY(!FileOperations::removePermanently({"/etc"}).ok);
    }

    void removePermanently()
    {
        const QString d = m_tmp.path() + "/rm";
        QDir().mkpath(d + "/t/u");
        write(d + "/t/u/x", "1");
        QVERIFY(FileOperations::removePermanently({d + "/t"}).ok);
        QVERIFY(!QFileInfo(d + "/t").exists());
    }

    void trashAndRestore()
    {
        const QString d = m_tmp.path() + "/trash";
        QDir().mkpath(d);
        write(d + "/borrame.txt", "adiós");
        const auto t = FileOperations::trash({d + "/borrame.txt"});
        if (!t.ok)
            QSKIP("moveToTrash is not available on this filesystem");
        QVERIFY(!QFileInfo(d + "/borrame.txt").exists());
        const QString inTrash = FileOperations::trashFilesDir() + "/borrame.txt";
        QVERIFY(QFileInfo(inTrash).exists());
        QVERIFY(FileOperations::isInTrash(inTrash));
        const auto r = FileOperations::restoreFromTrash({inTrash});
        QVERIFY2(r.ok, qPrintable(r.error));
        QVERIFY(QFileInfo(d + "/borrame.txt").exists());
    }

    void formatters()
    {
        QCOMPARE(Formatters::fileSize(12'400'000), QString("12.4 MB"));
        QCOMPARE(Formatters::fileSize(18'200), QString("18.2 KB"));
        QCOMPARE(Formatters::fileSize(512), QString("512 B"));
        QCOMPARE(Formatters::capacity(512'000'000'000), QString("512 GB"));
        QCOMPARE(Formatters::capacity(1'000'000'000'000), QString("1 TB"));
        QCOMPARE(Formatters::itemCount(1), QString("1 elemento"));
        QCOMPARE(Formatters::itemCount(24), QString("24 elementos"));
        const QDateTime now(QDate(2025, 8, 4), QTime(12, 0));
        QCOMPARE(Formatters::modified(QDateTime(QDate(2025, 8, 4), QTime(8, 45)), now), QString("Hoy, 8:45 AM"));
        QCOMPARE(Formatters::modified(QDateTime(QDate(2025, 8, 3), QTime(23, 30)), now), QString("Ayer, 11:30 PM"));
        QCOMPARE(Formatters::modified(QDateTime(QDate(2025, 8, 2), QTime(9, 0)), now), QString("02/08/2025"));
    }

private:
    QTemporaryDir m_tmp;
};

QTEST_APPLESS_MAIN(TestFileOperations)
#include "tst_fileoperations.moc"
