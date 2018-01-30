#!/bin/bash
#
# Auto-tune a Neural Machine Translation model 
# Using Sockeye and CMA-ES algorithm

n_population=$1

model_path="${generation_path}model_$(printf "%02d" "$n_population")/"
# path to evaluation score path
eval_scr="${model_path}metrics"

mkdir $model_path
touch ${eval_scr}

$py_cmd -m sockeye.train -s ${train_bpe}.$src \
                        -t ${train_bpe}.$trg \
                        -vs ${valid_bpe}.$src \
                        -vt ${valid_bpe}.$trg \
                        --num-embed $num_embed \
                        --rnn-num-hidden $rnn_num_hidden \
                        --rnn-attention-type $attention_type \
                        --max-seq-len $max_seq_len \
                        --checkpoint-frequency $checkpoint_frequency \
                        --num-words $num_words \
                        --word-min-count $word_min_count \
                        --max-updates $max_updates \
                        --num-layers $num_layers \
                        --rnn-cell-type $rnn_cell_type \
                        --batch-size $batch_size \
                        --min-num-epochs $min_num_epochs \
                        --embed-dropout $embed_dropout \
                        --keep-last-params $keep_last_params \
                        --use-tensorboard \
                        $device \
                        -o $model_path

$py_cmd reporter.py \
--trg ${generation_path}genes.scr \
--scr $eval_scr \
--pop $population \
--n-pop $n_population \
--n-gen $n_generation