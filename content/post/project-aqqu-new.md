---
title: "Aqqu New"
date: 2021-02-05T15:23:47+01:00
author: "Thomas Goette"
authorAvatar: "img/project_aqqu-new/avatar.png"
tags: [nlp, question answering, qa, knowledge base, ner, sparql, qlever, aqqu]
categories: [project]
image: "img/writing.jpg"
draft: true
---

Aqqu translates a given question into a sparql query and uses a sparql backend to get the answer to the question. Where the original aqqu used freebase as a backend and many additional external sources, this complete re-write uses data from wikidata exclusively.

<!--more-->

## Content

1. <a href="#introduction">Introduction</a>
1. <a href="#pre-processing">Pre-processing</a>
1. <a href="#pipeline">Steps in the Pipeline</a>

## <a id="#introduction"></a> Introduction

While the original Aqqu as published in [this paper](https://ad-publications.cs.uni-freiburg.de/CIKM_freebase_qa_BH_2015.pdf) and later improved by the chair still accomplishes impressive results, it has several drawbacks:

1. Its logic relies heavily on data from freebase which has not been updated for more than four years (it was shut down on 2 May 2016).
1. The code is heavily dependent on freebase.
1. The code has been updated, added to and partly refactored for more than five years, leading to partly unstructured and hard-to-read code.

These drawbacks led to this project, namely rewriting the entire software and basing it on freebase's successor [wikidata](https://www.wikidata.org/) instead.

## Requirements

Aqqu-new needs a way to get results for sparql queries. For now, it requires a working qlever backend (both for the pre-processing and the actual pipeline).

## <a id="#pre-processing"></a> Pre-processing

Before Aqqu-new can run, some pre-processing steps need to be done. If we would not do these, Aqqu-new would have to send sparql queries to its backend very frequently leading to longer query times.

### 1. Acquire data

First, we need to acquire some data about entities and relations. For that, we send a few sparql queries to the sparql backend and save the results in text files. The acquired information contains the label, popularity score and all aliases for all entities as well as all aliases for all relations. For the popularity score, we currently use the number of wikipedia sitelinks the entity has. 

### 2. Build indices

We could read the acquired data into memory whenever we load Aqqu-new. However, this would lead to load times of several minutes which slows down development a lot. Therefore, we use [rocksdb](https://rocksdb.org/) as a database to create an entity index and a relation index on the hard drive that Aqqu-new can use. This makes it possible to have a near-instant load time while still keeping the query time for the data low.

## <a id="#pipeline"></a> Steps in the Pipeline

Aqqu-new consists of several steps combining into a pipeline.

We run the pipeline with the question `Who designed Scrabble?`.

### 1. Tokenizer

We first run a tokenizer from [spaCy](https://spacy.io/) on the question.

This gives us `[Who, designed, Scrabble, ?]`.

### 2. Entity linker

We find the entities in the question that relate to an entity from wikidata. For that, we go through every subset of tokens in the question and check whether the entity index contains an alias of that text. If it does, we store the alias together with its wikidata id.

This gives us `[('Scrabble', 'Q170436'), ('Scrabble', 'Q7438686'), ('Scrabble', 'Q7438684'), ('Scrabble', 'Q7438683'), ('Scrabble', 'Q30612283'), ('Scrabble', 'Q18614280'), ('Scrabble', 'Q77807866')]`.  TODO bad example? all entities have the same alias

### 3. Pattern matcher

We predefined sparql query patterns that we now try to match. We use two patterns for now, namely ERT and TRE (E=entity, R=relation, T=target).

In this case, we send two queries to the sparql backend for every entity we found in the previous step, (`Q170436 ?r ?t` is one of the 14 queries). This gives us 90 matches or 90 candidates for a sparql query which could potentially answer the question. Three examples of candidates are `[Q170436-P287-?0, Q170436-P123-?0, Q170436-P1417-?0]`.

### 4. Relation matcher

We have only looked at the entities so far. Now we try to find matching relations in the candidates. For that, we ask our relation index for all aliases of the relation of a particular query and compare them to the tokens of the original question which have not already been matched to the entity. For every candidate, we store the relation matches.

In this case, let's look at the candidate `Q170436-P287-?0` (incidentally, this is the correct query). The relation `P287` has the following aliases:

- has designer
- designer

The token `Scrabble` from the question has been matched to the entity `Q170436` for this candidate. That leaves off the tokens `[Who, designed, ?]`. We now compare these tokens with the aliases from the relation. Since we look at the lemmata of the words, we match `designer (design)` to `designed (design)`.

### 5. Ranker

We generate features for every candidate, namely:

- General
  - `pattern_complexity`: The number of triples in the query. Since we use only one-triple templates at the moment, this feature is 1 for every candidate.
  - `token_coverage`: The number of question tokens which is covered by the entities and relations of the candidate, divided by the number of tokens.
  - `token_coverage_no_stop`: Same as above, but ignoring all stop words.
- Entities
  - `entity_score`: The popularity score (number of sitelinks) of the matched entity.
  - `entity_label_matches`: The number of entities which are matched by their label in the question (vs. by alias).
  - `n_entity_tokens`: The number of question tokens which belong to matched entities.
  - `n_entity_tokens_no_stop`: Same as above, but ignoring all stop words.
- Relations
  - `n_relation_word_matches`: TODO
  - `n_relation_no_stop_matches`
  - `n_relation_tokens`: The number of question tokens which belong to matched relations.
  - `n_relation_tokens_no_stop`: Same as above, but ignoring all stop words.

We assign every one of the generated candidates a score using simple hard-coded rules. We use four of the listed features:

1. `n_relation_word_matches`
1. `n_relation_no_stop_matches`
1. `entity_label_matches`
1. `entity_score`

The first of these is assigned the largest weight. The last one is assigned the lowest weight and is only used to decide between what would without it be draws. 

We then sort the candidates based on their score.

In our example case, the three best candidates with their scores are:

1. `Q170436-P287-?0 (score=0.51)`
1. `Q170436-P123-?0 (score=0.01)`
1. `Q170436-P1417-?0 (score=0.01)`

### 6. Candidate pruner

TODO

### 7. Candidate executor

We translate our candidates to sparql queries and send it to the qlever backend in order to get the actual answer to the question.

In our case, the answers for the three best ranked candidates are:

1. `Alfred Mosher Butts (Q922223)`
1. `Hasbro, Inc. (Q501476)`
1. `topic/Scrabble`

This way, we get the correct answer to our question.
