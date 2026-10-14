(async () => {
  // The C4 database's `clear` leaves the accessible description of the
  // diagram rendered before it in place (it does not clear the common
  // database), so on a page that renders several C4 diagrams a description
  // leaks into the diagrams after it. The port renders every diagram as
  // the first of its page; this gives each fixture the same start.
  const db = (await mermaid.mermaidAPI.getDiagramFromText('C4Context\nPerson(a, "A")')).db;
  const render = mermaid.render.bind(mermaid);
  mermaid.render = (...args) => {
    db.setAccDescription('');
    return render(...args);
  };
  return 'every diagram starts without a description';
})()
