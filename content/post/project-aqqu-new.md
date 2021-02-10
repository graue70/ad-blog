---
title: "Aqqu-New"
date: 2021-02-05T15:23:47+01:00
author: "Thomas Goette"
authorAvatar: "img/project_aqqu-new/avatar.png"
tags: [nlp, question answering, qa, knowledge base, ner, sparql, qlever, aqqu]
categories: [project]
image: "img/writing.jpg"
draft: true
---

Aqqu translates a given question into a sparql query and uses a sparql backend to get the answer to the question. While the original Aqqu uses freebase and some additional external sources, this new version uses nothing but wikidata.

<!--more-->

## Content

1. [Introduction](#introduction)
1. [Requirements](#requirements)
1. [Pre-processing](#pre-processing)
1. [Steps in the Pipeline](#pipeline)
1. [API documentation](#api-docs)
1. [Evaluation frontend](#evaluation-frontend)
1. [Evaluation](#evaluation)
1. [Possible improvements](#improvements)

## Introduction {#introduction}

While the original Aqqu as first published in [this paper](https://ad-publications.cs.uni-freiburg.de/CIKM_freebase_qa_BH_2015.pdf) still accomplishes impressive results, it has several drawbacks:

1. Its logic relies heavily on data from freebase which has not been updated for more than four years. (It was shut down on 2 May 2016.)
1. The program relies on several external data sources like the [clueweb dataset](http://lemurproject.org/clueweb09.php/) and the [Google News dataset](https://code.google.com/archive/p/word2vec/), which require manual updating or make running the program on a new machine harder.
1. The code has been updated, added to and partly refactored for more than five years, leading to partly unstructured and hard-to-maintain code.

These drawbacks led to this project, namely rewriting the entire program and basing it on freebase's successor [wikidata](https://www.wikidata.org/) instead.

Note that even though it is indeed a rewrite, major parts of the logic and some parts of the implementation were taken directly from the original Aqqu version which was developed mostly by Elmar Haussmann and later improved by Niklas Schnelle. Having read the original [Aqqu paper](https://ad-publications.cs.uni-freiburg.de/CIKM_freebase_qa_BH_2015.pdf) helps in understanding this version.

## Requirements {#requirements}

Aqqu-New needs a way to get results for sparql queries. For now, it requires a working [qlever backend](https://qlever.cs.uni-freiburg.de/) (both for the pre-processing and for running the actual pipeline).

## Pre-processing {#pre-processing}

Before Aqqu-New can run, some pre-processing needs to be done. This allows the program to answer some queries locally which otherwise would have to be sent to the sparql backend over the network, ultimately saving time when running the pipeline.

### 1. Acquire data

First, we need to acquire some data about entities and relations. For that, we send a few sparql queries to the sparql backend and save the results in text files. The acquired information contains the label, popularity score and all aliases for all entities as well as all aliases for all relations. For the popularity score, we currently use the number of wikipedia sitelinks the entity has.

Other than these files, there are no external data dependencies. Since the files can be generated automatically, the entire program is self-contained (except for the already mentioned required sparql backend).

### 2. Build indices

We could read the acquired data into memory whenever we load Aqqu-New. However, this would lead to load times of several minutes which slows down development a lot. Therefore, we use a [rocksdb](https://rocksdb.org/) database on the hard drive for an entity index and a relation index. This makes it possible to have a near-instant load time while still keeping the query time for the data low.

The two indices have to be built once. The program then re-uses the same indices whenever it is loaded.

## Steps in the Pipeline {#pipeline}

Aqqu-New consists of several steps combined into a pipeline.

As an example, we run the pipeline for the following question: `What is the capital of Bulgaria?`

### 1. Tokenizer

We first run a tokenizer from [spaCy](https://spacy.io/) on the question.

This gives us `[What, is, the, capital, of, Bulgaria, ?]`.

### 2. Entity linker

We find the entities in the question that relate to an entity from wikidata. For that, we go through every subset of consecutive tokens in the question and check whether the entity index contains an alias with that text. If it does, we store the alias together with its wikidata id.

This gives us `[('Bulgaria', 'Q219'), ('capital', 'Q5119'), ('capital', 'Q8137'), ('capital', 'Q58784'), ('capital', 'Q193893'), ('Bulgaria', 'Q55032081'), ('capital', 'Q98912'), ('Bulgaria', 'Q407383'), ('Bulgaria', 'Q390361'), ('Bulgaria', 'Q405228')]` (these are only ten of the 49 linked entities).

### 3. Pattern matcher {#pattern-matcher}

We predefined sparql query patterns that we try to match. We use two patterns for now, namely ERT and TRE (E=entity, R=relation, T=target). ERT is the first template described in Figure 1 of [the original Aqqu paper](https://ad-publications.cs.uni-freiburg.de/CIKM_freebase_qa_BH_2015.pdf). TRE swaps its subject and object. This template is not necessary when working with freebase because all data is (or should be) duplicated and therefore reachable with just one of the two templates. In wikidata, this duplication is tried to be avoided which makes both templates necessary in Aqqu-New. (See section [Possible improvements](#improvements) for an example of duplicated data in wikidata.)

For every linked entity we found in the previous step, we create one sparql query for every template and send it to the sparql backend.

In our example case, we have two templates and 49 linked entities leading to 98 queries in total. For the first matched entity `Q219`, these are the two queries:
```sparql
PREFIX wd: <http://www.wikidata.org/entity/>
PREFIX wikibase: <http://wikiba.se/ontology#>
SELECT DISTINCT ?relation WHERE {
  wd:Q219 ?relation ?object .
  ?relation_entity wikibase:directClaim ?relation .
}
```

```sparql
PREFIX wd: <http://www.wikidata.org/entity/>
PREFIX wikibase: <http://wikiba.se/ontology#>
SELECT DISTINCT ?relation WHERE {
  ?subject ?relation wd:Q219 .
  ?relation_entity wikibase:directClaim ?relation .
}
```

The results give us 946 pattern matches or 946 candidates for a sparql query which could potentially answer the question. Three examples of generated candidates are `Q219-P36-?0`, `?0-P1376-Q219` and `Q390361-P1376-?0` (leaving out the prefixes and keywords of the respective sparql query).

### 4. Relation matcher

We have only looked at the entities so far. Now we try to find matching relations in the candidates. For that, we ask the relation index for all aliases of the relation of a particular query candidate and compare them to the tokens of the original question which have not already been matched to the entity. For every candidate, we store the relation matches.

In this case, let's look at the candidate `Q219-P36-?0`. The relation `P36` has the following aliases, among others:

- county seat
- court residence
- chef-lieu
- capital

The token `Bulgaria` from the question has been matched to the entity `Q219` for this particular candidate. That leaves the tokens `[What, is, the, capital, of, ?]` for potential relation matches. We now compare these tokens with the aliases from the relation. We match the word 'capital' (label of P36) to the same word in the question.

### 5. Ranker

We generate the following features for every candidate:

- Entities
  - `entity_score`: The popularity score (number of sitelinks) of the matched entity.
  - `entity_label_matches`: The number of entities which are matched by their label in the question (vs. by alias).
  - `n_entity_tokens`: The number of question tokens which belong to matched entities.
  - `n_entity_tokens_no_stop`: Same as above, but ignoring all stop words.
- Relations
  - `n_relation_word_matches`: The number of relations that were matched to words in the question (at most one for our simple templates).
  - `n_relation_no_stop_matches`: Same as above, but ignoring all stop words.
  - `n_relation_tokens`: The number of question tokens which were matched to relations.
  - `n_relation_tokens_no_stop`: Same as above, but ignoring all stop words.
- General
  - `pattern_complexity`: The number of triples in the query. Since we use only one-triple templates at the moment, this feature has value 1 for every candidate.
  - `token_coverage`: The number of question tokens which are covered by the entities and relations of the candidate, divided by the number of all tokens.
  - `token_coverage_no_stop`: Same as above, but ignoring all stop words.

We assign every one of the generated candidates a score using a simple hard-coded formula. We only use these four of the listed features:

1. `n_relation_word_matches`
1. `n_relation_no_stop_matches`
1. `entity_label_matches`
1. `entity_score`

The first of these is assigned the largest weight. The last one is assigned the lowest weight and is only used to decide between what would without it be draws. 

We then sort the candidates based on their score.

Four our example question, these are the scores of the three candidates from the pattern matching step. They are also the candidates with the best scores:

1. `Q219-P36-?0 (score=1.61)`
1. `?0-P1376-Q219 (score=1.61)`
1. `Q390361-P1376-?0 (score=1.5)`

### 6. Candidate executor

We translate our candidates to sparql queries and send them to the qlever backend in order to get the actual answer to the question. In case the result is a wikidata entity, we also query its english label.

In our example case, the answers for the three best ranked candidates are:

1. `Sofia (Q472)`
1. `Sofia (Q472)`
1. `Breznik Municipality (Q2405103)`

The highest-ranked candidate leads to the correct answer to our original question in this case.

## API documentation {#api-docs}

The API includes an interactive documentation website implementing the [OpenAPI specification](https://swagger.io/specification/) where you can also try it out. It looks like this:

![interactive API documentation](/img/project_aqqu-new/screenshot_api_docs.png)

## Evaluation frontend {#evaluation-frontend}

This project includes a separate frontend for viewing evaluation results in table format. It looks like this:

![evaluation frontend](/img/project_aqqu-new/screenshot_evaluation_frontend.png)

## Evaluation {#evaluation}

### Dataset {#dataset}

We use the test set of the [wikidata-simplequestions](https://github.com/askplatypus/wikidata-simplequestions) dataset for evaluation. Specifically we use the file `annotated_wd_data_test_answerable.txt` which contains only questions which are theoretically answerable with the data from wikidata. It contains 5622 questions in total, each of them with the gold answer and the gold sparql query leading to the correct answer. 4296 (76%) of those gold queries follow the ERT pattern and 1326 (24%) follow the TRE template (see section [Pattern matcher](#pattern-matcher) for an explanation of the patterns).

If we run the gold sparql queries from the dataset as a pipeline and evaluate it against the gold answers from the dataset, we get the following results:

![evaluation results perfect](/img/project_aqqu-new/screenshot_evaluation_results_perfect.png)

(The run with the word 'forward' contains only the queries with the ERT pattern and the word 'reverse' contains only the queries with the TRE pattern.) We see that the results on the two subset are very different (compare average F1 of 10% vs 93%). We know of two problems leading to a lower score for the TRE queries:

1. Many of the TRE questions ask for examples of a group, for example: 'Name a baseball player'. The gold answer is exactly one baseball player (the gold answer set has length one for every question in the dataset). The result to the gold sparql query contains all the 32,000 baseball players in wikidata. This leads to a high precision and a very low recall.
1. Every candidate sparql query that Aqqu-New sends to its sparql backend currently uses a limit of 300 (meaning the result set is cut off at length 300). That means that in the baseball player example, we might even get a precision of zero because the gold answer baseball player is not part of the 300 returned baseball players. This is of course not a problem of the dataset but of our program but it is questionable whether it would be better overall to enable result sets of length 40,000 (and even that limit would be too low for some queries).

Because of the mentioned problems with the TRE patterns in the dataset, we decided to only use the ERT part of the dataset for now.

### Evaluation results

The described pipeline achieves an average F1 score of 0.31 on the dataset. For comparison, a ranker using a random scoring function achieves an average F1 score of 0.01. You can see the two results here:

![evaluation results](/img/project_aqqu-new/screenshot_evaluation_results.png)

## Possible improvements {#improvements}

There are many possible improvements, some of which are already implemented in the original Aqqu and need to migrated:

1. At the moment, every question with at least one candidate is answered. It might make sense to implement a limit score which means that some questions stay un-answered. This feature could be tested with the dataset `annotated_wd_data_test.txt` (see section [Dataset](#dataset) for an explanation of the file) which also contains questions which are not answerable with wikidata.
1. The ranking is currently done by manually determined, hard-coded scoring rules. The score should instead be calculated by some machine learning algorithm, possibly using neural networks. There are also probably some more features which would help the ranking process.
1. At the moment, we use only query templates with one triple. This should be generalized. This would also mean that Aqqu-New would not have to rely solely on the truthy version of wikidata, making questions like `Who has been chancellor of Germany?` (as opposed to `Who is chancellor of Germany?`) possible. (Note that the dataset that we use only contains the mentioned ERT and TRE patterns. For training and testing other templates, we would need another dataset.)
1. There is no answer-type matching. This means that it is hard to differentiate between questions like `Where was Angela Merkel born?` and `When was Angela Merkel born?`. The current pipeline will give both answers the same score because both candidates have the exact same feature values.
1. Some queries take a long time to complete. This is due to the pattern matcher sending lots of sparql queries to the backend in case lots of entities were matched. These are some ideas for how the problem could be solved:
  1. We could drop some of the irrelevant entity matches before doing the pattern matching.
  1. We could try to lower the amount of queries that need to be sent to the sparql backend by combining multiple queries into one.
  1. Another option would be to pre-compute patterns for entities, but this might not be feasible for all entities due to the amount of disk space that would require, especially when adding more templates.
1. There are some cases where data is duplicated in wikidata which means that two different queries would lead to the correct answer. (The Bulgaria example above is such a case. Wikidata knows both that Sofia is the capital of Bulgaria and that Bulgaria has the capital Sofia. The symmetric relation 'married to' is another example where this occurs.) Instead of returning two identical results (originating from different query candidates), maybe it would make sense to combine the results into one (possibly with a higher score)?
1. It would be great to be able to use given entity linking information as for example provided by the [aqqu-frontend](https://github.com/ad-freiburg/aqqu-frontend). (Note that this probably means that we have to find a replacement for the spaCy pipeline API or write our own. We don't think it is flexible enough to be able to accommodate this feature. A possible replacement option to look into is the [pipeline API from sklearn](https://scikit-learn.org/stable/modules/generated/sklearn.pipeline.Pipeline.html#sklearn.pipeline.Pipeline).)
