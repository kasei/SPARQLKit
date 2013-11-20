SPARQLKit
=========

An implementation of the SPARQL query language in Objective-C.
---------------

This code is a work-in-progress, aiming to implement a full SPARQL query and update engine
in Objective-C. The design is based on trait/role-based programming, where possible
allowing for natural extensibility and component selection/replacement
(e.g. using the Raptor RDF parser and a triple-store backed by the OS X Address Book).
