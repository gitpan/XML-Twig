<?xml version="1.0" standalone="no"?>
<!DOCTYPE doc SYSTEM "test2_2.dtd"[
<!ENTITY e1 SYSTEM "e1.gif" NDATA gif>
<!ENTITY e2 "entity2">
<!ENTITY e3 SYSTEM "pic.jpeg" PUBLIC "JPEG" >]>
<doc id="doc1"><section id="section1"><intro id="intro1"><para id="paraintro1">S1 I1</para><para id="paraintro2">S1 I2</para></intro><title id="title1" no="1">S1 Title</title><para id="para1">S1 P1</para><para id="para2">S2 P2</para><note id="note1"><para id="paranote1">Note P1</para></note><para id="para3">S1 <xref refid="section2"/>para 3</para></section><section id="section2"><intro id="intro2"><para id="paraintro3">S2 intro</para></intro><title id="title2" no="2">S2 Title</title><para id="para4">S2 P1</para><para id="para5">S2 P2</para><para id="para6">S2 P3</para></section><annex id="annex1"><title id="titleA" no="A">Annex Title</title><para id="paraannex1">Annex P1</para><para id="paraannex2">Annex P2</para></annex></doc>