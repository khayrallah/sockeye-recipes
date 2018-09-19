## Tutorial for SCALE18 

This is a recipe for training NMT systems on SCALE18 data. 
We will assume that all the data have already been preprocessed, in particular tokenized and BPE'd. In other words, we can start training right away. The goal of this tutorial to learn how to customize a hyperparameter file for your own purpose. 


### Step 0: Setup

We assume all data is at `D=/exp/scale18/mt/data` and you have a directory `U=/exp/username/sockeye-tutorial` where you will be working. For the other grid (CLSP), you may have instead: `D=/export/a06/scale18mt/data` and you have a directory `U=/export/a06/username/sockeye-tutorial`.

Let's start by going to your directory and creating a `$workdir` for all your experiments (let's assume you want to do TED de-en):

```bash
cd $U
mkdir -p de-en/ted
cd de-en/ted
```

### Step 1: Create hyperparameter file

We will start with a hyperparameter file template. Copy anything from `$rootdir/hpm` to your current directory, e.g.:

```bash
cp $rootdir/hpm/rm1.hpm-template mymodel1.hpm
```

Now, edit rm1.hpm, in particular editing the following basic paths and src/trg names:

* workdir=/exp/username/sockeye-tutorial/de-en/ted
* modeldir=$workdir/mymodel1 (this can be anything you like)
* rootdir= whereever you installed sockeye-recipes
* src=de
* trg=en

Also, we need to specify where to find the BPE'd data by setting `{train,valid}_bpe_{src,trg}`. Note that we don't need to set `{train,valid}_tok` (which is the tokenized file before BPE), because we are starting with BPE'd files. So just set the following:

```
datadir=/exp/scale18/mt/data/de-en/ted/
train_bpe_src=$datadir/ted.train.bpe.$src
valid_bpe_src=$datadir/ted.dev.bpe.$src
train_bpe_trg=$datadir/ted.train.bpe.$trg
valid_bpe_trg=$datadir/ted.dev.bpe.$trg
```

The above settings will stay the same for different training runs on this same data. The NMT model architecture hyperparameters we may be interested include:

* num_embed: size of word embeddings
* rnn_num_hidden: size of rnn hidden layer
* rnn_layers: number of stacked encoder/decoder layers
* num_words: vocabulary size of source and target

Hyperparameters for training include: 
* batch_size: sockeye-recipes default uses word batching, so this is number of words per batch
* optimizer: adam, adadelta, etc.
* initial_learning_rate: this is very important
* checkpoint_frequency: Sockeye saves a model after this many updates (which corresponds to number of minibatchs processed). Our default of 4000 seems generally reasonable. Reduce this if you want more frequent checkpoints, but note this affects two things: (a) the learning rate schedule and convergence criteria are based on number of checkpoints, so changing this may affect training speed and model at convergence. (b) if decode_and_evaluate is set to anything except 0 (meaning that we will start a separate decoder process for the validation data), having small checkpoint_frequency may mean these separate jobs get queued up--not a big deal, but slows down the overall training script. 
* max_num_epochs and max_updates: if either of these are met, training stops. We can of course stop the training process at any point and use the best model so far. Usually it is safe to set this at a high value. 
* keep_last_params: how many checkpoint models to keep. Set to -1 to keep all, but be wary of disk space

See [example.hpm](example.hpm) for a concrete example. 

### Step 2: Train

Train the model with:
```bash
qsub -S /bin/bash -V -cwd -q gpu.q -l gpu=1,h_rt=24:00:00,num_proc=2,mem_free=20G -j y path/to/sockeye-recipes/scripts/train.sh -p mymodel1.hpm -e sockeye_gpu
[CLSP grid] qsub -S /bin/bash -V -cwd -pe smp 2 -l gpu=1,mem_free=20G,ram_free=20G -j y path/to/sockeye-recipes/scripts/train.sh -p mymodel1.hpm -e sockeye_gpu

```

Note we are requesting 1 GPU and 2 CPU slots. This is the recommended setting. 

While waiting, check these files in $modeldir: `cmdline.log` is sockeye-recipe's log and documents device information and time. `log` is sockeye's log and contains detailed training information. `metrics` contains useful statistics computed at each checkpoint. 

### Step 3: Translate

After we have at least one checkpoint, we can try translating the test set in `/exp/scale18/mt/data/de-en/ted/ted.test.bpe.de`:

```bash
qsub -S /bin/bash -V -cwd -q gpu.q -l gpu=1,h_rt=00:50:00,mem_free=20G -j y path/to/sockeye-recipes/scripts/translate.sh -i /exp/scale18/mt/data/de-en/ted/ted.test.bpe.de -o mymodel1/ted.test.tok.en.1best -p mymodel1.hpm -e sockeye_gpu -s
[CLSP grid] qsub -S /bin/bash -V -cwd -l gpu=1,mem_free=20G,ram_free=20G -j y path/to/sockeye-recipes/scripts/translate.sh -i /exp/scale18/mt/data/de-en/ted/ted.test.bpe.de -o mymodel1/ted.test.tok.en.1best -p mymodel1.hpm -e sockeye_gpu -s
```

Note that in this case, we are translating an input file that is already BPE'd. So we add the `-s` flag which skips BPE processing on the input. 

## Continued Training

It is easy to perform continued training via Sockeye (i.e. initialize model parameters from a previous training run and starting another training run, possibly on different datasets). This is an useful technique for domain adaptation, among others.

To enable continued training, just add one more variable to your hyperparameter file: `initmodeldir`. This should point to the `$modeldir` of some previous run, such as `/exp/username/sockeye-tutorial/de-en/ted/myexample1/` from before. 

For the purposes of demonstrating continued training for domain adaptation, let's use a large pre-trained model located at `/home/hltcoe/kduh/p/scale/scale2018/sockeye-nmt/de-en/generaldomain/rm1`. Create a new hyperparameter file `my-ct1.hpm` and add the variable anywhere:

```bash
cp example-ct.hpm my-ct1.hpm
echo "initmodeldir=/home/hltcoe/kduh/p/scale/scale2018/sockeye-nmt/de-en/generaldomain/rm1" >> my-ct1.hpm
```

Be sure to also change the `$modeldir`, `$workdir`, `$rootdir` to your own settings. 

Also, continued training assume that the model architectures are the same for the initial and the new model. Sockeye will do a check and if the hyperparameters don't match, it will still run if it can (e.g. continued training a 1-layer RNN from a 2-layer initial model is doable even if it is not guaranteed the results will be good), and will stop if it can't. (Minor note: the above generaldomain model is based on the 2-layer rm1 template)

Running the following diff will show how the hpm is simply one extra line and some modifications to make sure the hyperparameters match up with the initial model. 
```
diff example-ct.hpm example.hpm
```

Finally, we train using `continue-train.sh`, invoked in the same way as `train.sh`:

```bash
qsub -S /bin/bash -V -cwd -q gpu.q -l gpu=1,h_rt=24:00:00,num_proc=2,mem_free=20G -j y path/to/sockeye-recipes/scripts/continue-train.sh -p my-ct1.hpm -e sockeye_gpu
```

If you inspect the internals of `continue-train.sh` script, you will see that it is very similar to `train.sh`, except for three additional flags:

```bash
--params $initmodeldir/params.best \
--source-vocab $initmodeldir/vocab.src.0.json \
--target-vocab $initmodeldir/vocab.trg.0.json \
```

Basically, `--params` reads the best model from `$initmodeldir`, and the `{source,target}-vocab` are vocab files from the initial model that need to be fixed and provided to the new run to ensure the vocabulary-to-integer mapping is consistent. 

If more variants of continued training are desired, it is recommended to create a script similar to `continue-train.sh` with additional flags like this for your own purposes. 