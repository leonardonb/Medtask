String two(int n) => n.toString().padLeft(2, '0');
String dtFmt(DateTime d) =>
    '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
