/*
 * Copyright 2014 Mortar Data Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "as is" Basis,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

----------------------------------------------------------------------------------------------------
/*
 * This file contains alternative versions of the Mortar recommendation algorithm. The standard algorithm is contained in macros/recommender.pig. 
 */
----------------------------------------------------------------------------------------------------




/* 
 * This is an alternative of recsys__GetItemItemRecommendations
 * 
 * This macro will create item-to-item recommendations based on user-item signals and item-item signals.
 * 
 * Input:
 *      user_item_signals: { (user:chararray, item:chararray, weight:float) }
 *      item_item_signals: { (item_A:chararray, item_B:chararray, weight:float) }
 * Output:
 *      item_item_recs: { (item_A:chararray, item_B:chararray, weight:float, raw_weight:float, rank:int) }
 */
define recsys__GetItemItemRecommendations_AddItemItem(user_item_signals, item_item_signals) returns item_item_recs {

    -- Convert user_item_signals to an item_item_graph
    ii_links_raw, item_weights   =   recsys__BuildItemItemGraph(
                                       $user_item_signals,
                                       $LOGISTIC_PARAM,
                                       $MIN_LINK_WEIGHT,
                                       $MAX_LINKS_PER_USER
                                     );

    -- Combines item links generated and item item signals, while recalculating overall 
    -- weights of individual items
    combined_ii, combined_item_weights =   recsys__SumItemItemSignals(
                                               ii_links_raw,
                                               $item_item_signals,
                                               item_weights
                                           ); 

    -- Adjust the weights of the graph to improve recommendations.
    ii_links                    =   recsys__AdjustItemItemGraphWeight(
                                        combined_ii,
                                        combined_item_weights,
                                        $BAYESIAN_PRIOR
                                    );

    -- Use the item-item graph to create item-item recommendations.
    item_item_recs_raw =  recsys__BuildItemItemRecommendationsFromGraph(
                           ii_links,
                           $NUM_RECS_PER_ITEM, 
                           $NUM_RECS_PER_ITEM
                       );
    -- item_item_recs_raw need to be filtered
    $item_item_recs = filter item_item_recs_raw 
                          by  (item_B is not null) 
                          and (item_A is not null) 
                          and (weight is not null) 
                          and (raw_weight is not null) 
                          and (rank is not null);

};

/* 
 * This is an alternative of recsys__GetItemItemRecommendations
 *
 * This macro will create item-to-item recommendations based on user-item signals. 
 * This algorithm will utilize diversify item-item links. Similar items based on the same metadata 
 * will be reduced in weight to try and generate a more diverse set of recommendations. 
 * 
 * Input:
 *      user_item_signals: { (user:chararray, item:chararray, weight:float) }
 *      metadata: { (item:chararray, metadata_field:chararray) }
 * Output:
 *      item_item_recs: { (item_A:chararray, item_B:chararray, weight:float, raw_weight:float, rank:int) }
 */
define recsys__GetItemItemRecommendations_DiversifyItemItem(user_item_signals, metadata) returns item_item_recs {

    -- Convert user_item_signals to an item_item_graph
    ii_links_raw, item_weights   =   recsys__BuildItemItemGraph(
                                       $user_item_signals,
                                       $LOGISTIC_PARAM,
                                       $MIN_LINK_WEIGHT,
                                       $MAX_LINKS_PER_USER
                                     );

    -- Adjust the weights of the graph to improve recommendations.
    ii_links                    =   recsys__AdjustItemItemGraphWeight(
                                        ii_links_raw,
                                        item_weights,
                                        $BAYESIAN_PRIOR
                                    );

    -- Adjust the weights of the graph to improve recommendations
    ii_link_diverse            =   recsys__DiversifyItemItemLinks(ii_links, $metadata);

    -- Use the item-item graph to create item-item recommendations.
    $item_item_recs =  recsys__BuildItemItemRecommendationsFromGraph(
                           ii_link_diverse, -- modified to use adjusted graph
                           $NUM_RECS_PER_ITEM, 
                           $NUM_RECS_PER_ITEM
                       );
};


/* 
 * This is an alternative of recsys__GetItemItemRecommendations
 *
 * This takes an additional input of a set of source items to handle the case where not every
 * item is in stock or needs a recommendation; but the links to those items may still be valuable
 * in the shortest paths traversal. It then builds the item-item recommendations from this traversal.
 *
 * 
 * Input:
 *      user_item_signals: { (user:chararray, item:chararray, weight:float) }
 *      source_items: { (item:chararray) }
 * Output:
 *      item_item_recs: { (item_A:chararray, item_B:chararray, weight:float, raw_weight:float, rank:int) }
 */
define recsys__GetItemItemRecommendations_WithSourceItems(user_item_signals, source_items) returns item_item_recs {

    -- Convert user_item_signals to an item_item_graph
    ii_links_raw, item_weights   =   recsys__BuildItemItemGraph(
                                       $user_item_signals,
                                       $LOGISTIC_PARAM,
                                       $MIN_LINK_WEIGHT,
                                       $MAX_LINKS_PER_USER
                                     );

    -- Adjust the weights of the graph to improve recommendations.
    ii_links                    =   recsys__AdjustItemItemGraphWeight(
                                        ii_links_raw,
                                        item_weights,
                                        $BAYESIAN_PRIOR
                                    );


    -- Use the item-item graph to create item-item recommendations.
      -- calls different macro from standard recsys code
    $item_item_recs =  recsys__BuildItemItemRecommendationsFromGraph_withSourceItems(
                           ii_links,
                           $source_items, -- Added on to represent items in stock or not
                           $NUM_RECS_PER_ITEM, 
                           $NUM_RECS_PER_ITEM
                       );
};


/* 
 * This is an alternative of recsys__GetItemItemRecommendations
 *
 * This macro will create item-to-item recommendations based on user-item signals and uses a popularity boost
 * to improve results. 
 *
 * 
 * Input:
 *      user_item_signals: { (user:chararray, item:chararray, weight:float) }
 * Output:
 *      item_item_recs: { (item_A:chararray, item_B:chararray, weight:float, raw_weight:float, rank:int) }
 */
define recsys__GetItemItemRecommendations_PopularityBoost(user_item_signals) returns item_item_recs {

    -- Convert user_item_signals to an item_item_graph
    ii_links_raw, item_weights   =   recsys__BuildItemItemGraph(
                                       $user_item_signals,
                                       $LOGISTIC_PARAM,
                                       $MIN_LINK_WEIGHT,
                                       $MAX_LINKS_PER_USER
                                     );

    -- Adjust the weights of the graph to improve recommendations.
    ii_links                    =   recsys__AdjustItemItemGraphWeight_withPopularityBoost(
                                        ii_links_raw,
                                        item_weights,
                                        $BAYESIAN_PRIOR,
                                        'SQRT'
                                    );


    -- Use the item-item graph to create item-item recommendations.
      -- calls different macro from standard recsys code
    $item_item_recs =  recsys__BuildItemItemRecommendationsFromGraph(
                           ii_links,
                           $NUM_RECS_PER_ITEM, 
                           $NUM_RECS_PER_ITEM
                       );
};
