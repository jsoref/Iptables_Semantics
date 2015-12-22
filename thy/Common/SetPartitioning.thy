(*Author: Max Haslbeck, 2015*)
theory SetPartitioning
imports Main
        (*"~~/src/HOL/Library/Code_Target_Nat" (*!*)*)
begin

(* disjoint, ipPartition definitions *)

definition disjoint :: "'a set set \<Rightarrow> bool" where
  "disjoint ts \<equiv> \<forall>A \<in> ts. \<forall>B \<in> ts. A \<noteq> B \<longrightarrow> A \<inter> B = {}"

text_raw{*We will call two partitioned sets \emph{complete} iff @{term "\<Union> ss = \<Union> ts"}.*}


text{*The condition we use to partition a set. If this holds and 
      @{term A} is the set of ip addresses in each rule in a firewall,
      then @{term B} is a partition of @{term "\<Union> A"} where each member has the same behavior
      w.r.t the firewall ruleset.*}
text{*@{term A} is the carrier set and @{term B}* should be a partition of @{term "\<Union> A"} which fulfills the following condition:*}
definition ipPartition :: "'a set set \<Rightarrow> 'a set set \<Rightarrow> bool" where
  "ipPartition A B \<equiv> \<forall>a \<in> A. \<forall>b \<in> B. a \<inter> b = {} \<or> b \<subseteq> a"

definition disjoint_list :: "'a set list \<Rightarrow> bool" where
  "disjoint_list ls \<equiv> distinct ls \<and> disjoint (set ls)"

(*internal*)
fun disjoint_list_rec :: "'a set list \<Rightarrow> bool" where
  "disjoint_list_rec [] = True" |
  "disjoint_list_rec (x#xs) = (x \<inter> \<Union> set xs = {} \<and> disjoint_list_rec xs)"

lemma "disjoint_list ts \<Longrightarrow> disjoint_list_rec ts"
  apply(induction ts)
   apply(simp)
  apply(simp add: disjoint_list_def disjoint_def)
  by fast

lemma "disjoint_list_rec ts \<Longrightarrow> disjoint (set ts)"
  apply(induction ts)
   apply(simp_all add: disjoint_list_def disjoint_def)
  by fast


(* FUNCTIONS *)

definition addSubsetSet :: "'a set \<Rightarrow> 'a set set \<Rightarrow> 'a set set" where
  "addSubsetSet s ts = insert (s - \<Union>ts) ((op \<inter> s) ` ts) \<union> ((\<lambda>x. x - s) ` ts)"

fun partitioning :: "'a set list \<Rightarrow> 'a set set \<Rightarrow> 'a set set" where
  "partitioning [] ts = ts" |
  "partitioning (s#ss) ts = partitioning ss (addSubsetSet s ts)"


(* SIMPLE TESTS *)

definition test_set_list :: "nat set list" where "test_set_list = [{1,2},{3,4},{5,6,7},{6},{10}]" 

lemma "partitioning test_set_list {} = {{10}, {6}, {5, 7}, {}, {3, 4}, {1, 2}}" by eval
lemma "\<Union> (set test_set_list) = \<Union> (partitioning test_set_list {})" by eval
lemma "disjoint (partitioning test_set_list {})" by eval
lemma "ipPartition (set test_set_list) (partitioning test_set_list {})" by eval

(* OTHER LEMMAS *)

lemma "ipPartition A {}" by(simp add: ipPartition_def)

lemma ipPartitionUnion: "ipPartition As Cs \<and> ipPartition Bs Cs \<longleftrightarrow> ipPartition (As \<union> Bs) Cs"
 unfolding ipPartition_def by fast


(* addSubsetSet LEMMAS *)

lemma disjointAddSubset: "disjoint ts \<Longrightarrow> disjoint (addSubsetSet a ts)" 
  by (auto simp add: disjoint_def addSubsetSet_def)

lemma coversallAddSubset:"\<Union> (insert a ts) = \<Union> (addSubsetSet a ts)" 
  by (auto simp add: addSubsetSet_def)

lemma ipPartioningAddSubset0: "disjoint ts \<Longrightarrow> ipPartition ts (addSubsetSet a ts)"
  apply(simp_all add: addSubsetSet_def ipPartition_def)
  apply(safe)
    apply blast
   apply(simp_all add: disjoint_def)
   apply blast+
  done

lemma ipPartitioningAddSubset1: "disjoint ts \<Longrightarrow> ipPartition (insert a ts) (addSubsetSet a ts)"
  apply(simp_all add: addSubsetSet_def ipPartition_def)
  apply(safe)
    apply blast
   apply(simp_all add: disjoint_def)
   apply blast+
done

lemma addSubsetSetI:
"s - \<Union>ts \<in> addSubsetSet s ts"
"t \<in> ts \<Longrightarrow> s \<inter> t \<in> addSubsetSet s ts"
"t \<in> ts \<Longrightarrow> t - s \<in> addSubsetSet s ts"
unfolding addSubsetSet_def by blast+
  
lemma addSubsetSetE:
  assumes "A \<in> addSubsetSet s ts"
  obtains "A = s - \<Union>ts" | T where "T \<in> ts" "A = s \<inter> T" | T where "T \<in> ts" "A = T - s"
  using assms unfolding addSubsetSet_def by blast
  
lemma Union_addSubsetSet [simp]: "\<Union>addSubsetSet b As = b \<union> \<Union>As"
  unfolding addSubsetSet_def by auto

lemma addSubsetSetCom: "addSubsetSet a (addSubsetSet b As) = addSubsetSet b (addSubsetSet a As)"
proof -
  {
    fix A a b assume "A \<in> addSubsetSet a (addSubsetSet b As)"
    hence "A \<in> addSubsetSet b (addSubsetSet a As)"
    proof (rule addSubsetSetE)
      assume "A = a - \<Union>addSubsetSet b As"
      hence "A = (a - \<Union>As) - b" by auto
      thus ?thesis by (auto intro: addSubsetSetI)
    next
      case (goal2 T)
      have "A = b \<inter> (a - \<Union>As) \<or> (\<exists>S\<in>As. A = b \<inter> (a \<inter> S)) \<or> (\<exists>S\<in>As. A = (a \<inter> S) - b)"
        by (rule addSubsetSetE[OF goal2(1)]) (auto simp: goal2(2))
      thus ?thesis by (blast intro: addSubsetSetI)
    next
      case (goal3 T)
      have "A = b - \<Union>addSubsetSet a As \<or> (\<exists>S\<in>As. A = b \<inter> (S - a)) \<or> (\<exists>S\<in>As. A = (S - a) - b)"
        by (rule addSubsetSetE[OF goal3(1)]) (auto simp: goal3(2))
      thus ?thesis by (blast intro: addSubsetSetI)
    qed
  }
  thus ?thesis by blast
qed

lemma ipPartitioningAddSubset2: "ipPartition {a} (addSubsetSet a ts)"
  apply(simp_all add: addSubsetSet_def ipPartition_def) 
  by blast

lemma disjointPartitioning_helper :"disjoint As \<Longrightarrow> disjoint (partitioning ss As)"
  proof(induction ss arbitrary: As)
  print_cases
  case Nil thus ?case by(simp)
  next
  case (Cons s ss)
    from Cons.prems disjointAddSubset have d: "disjoint (addSubsetSet s As)" by fast
    from Cons.IH d have "disjoint (partitioning ss (addSubsetSet s As))" .
    thus ?case by simp
  qed

lemma disjointPartitioning:"disjoint (partitioning ss {})"
  proof -
    have "disjoint {}" by(simp add: disjoint_def)
    from this disjointPartitioning_helper show ?thesis by fast
  qed

lemma coversallPartitioning_helper:"\<Union> (set ts \<union> As) = \<Union> (partitioning ts As)"
  apply(induction ts arbitrary: As)
   apply(simp_all)
  apply(metis Sup_insert Union_Un_distrib  coversallAddSubset sup.left_commute)
done

lemma coversallPartitioning:"\<Union> (set ts) = \<Union> (partitioning ts {})"
by (metis coversallPartitioning_helper sup_bot.right_neutral)

lemma "\<Union> As = \<Union> Bs \<Longrightarrow> ipPartition As Bs \<Longrightarrow> ipPartition As (addSubsetSet a Bs)"
  by(auto simp add: ipPartition_def addSubsetSet_def)


lemma ipPartitionSingleSet: "ipPartition {t} (addSubsetSet t Bs) 
             \<Longrightarrow> ipPartition {t} (partitioning ts (addSubsetSet t Bs))"
  apply(induction ts arbitrary: Bs t)
   apply(simp_all)
  by (metis addSubsetSetCom ipPartitioningAddSubset2)

lemma ipPartitioning_helper: "disjoint As \<Longrightarrow> ipPartition (set ts) (partitioning ts As)"
  proof(induction ts arbitrary: As)
  print_cases
  case Nil thus ?case by(simp add: ipPartition_def)
  next
  case (Cons t ts)
    from Cons.prems ipPartioningAddSubset0 have d: "ipPartition As (addSubsetSet t As)" by blast
    from Cons.prems Cons.IH d disjointAddSubset ipPartitioningAddSubset1
    have e: "ipPartition (set ts) (partitioning ts (addSubsetSet t As))" by blast
    from ipPartitioningAddSubset2 Cons.prems 
    have "ipPartition {t} (addSubsetSet t As)" by blast 
    from this Cons.prems ipPartitionSingleSet
    have f: "ipPartition {t} (partitioning ts (addSubsetSet t As))" by fast
    have "set (t#ts) = insert t (set ts)" by auto
    from ipPartitionUnion have "\<And> As Bs Cs. ipPartition As Cs \<Longrightarrow> ipPartition Bs Cs \<Longrightarrow> ipPartition (As \<union> Bs) Cs" by fast
    with this e f 
    have "ipPartition (set (t # ts)) (partitioning ts (addSubsetSet t As))" by fastforce
    thus ?case by simp
 qed

lemma ipPartitioning: "ipPartition (set ts) (partitioning ts {})"
  proof -
    have "disjoint {}" by(simp add: disjoint_def)
    from this ipPartitioning_helper show ?thesis by fast
  qed

(* OPTIMIZATION PROOFS *)

lemma inter_dif_help_lemma: "A \<inter> B = {}  \<Longrightarrow> B - S = B - (S - A)"
  by blast

lemma disjoint_list_lem: "disjoint_list ls \<Longrightarrow> \<forall>s \<in> set(ls). \<forall>t \<in> set(ls). s \<noteq> t \<longrightarrow> s \<inter> t = {}"
  apply(induction ls)
  by(simp_all add: disjoint_list_def disjoint_def)

lemma disjoint_list_empty: "disjoint_list []"
  by (simp add: disjoint_list_def disjoint_def)

lemma disjoint_sublist: "disjoint_list (t#ts) \<Longrightarrow> disjoint_list ts"
  apply(induction ts arbitrary: t)
  by(simp_all add: disjoint_list_empty disjoint_list_def disjoint_def)

fun intersection_list :: "'a set \<Rightarrow> 'a set list \<Rightarrow> 'a set list" where
  "intersection_list _ [] = []" |
  "intersection_list s (t#ts) = (s \<inter> t)#(intersection_list s ts)"

fun intersection_list_opt :: "'a set \<Rightarrow> 'a set list \<Rightarrow> 'a set list" where
  "intersection_list_opt _ [] = []" |
  "intersection_list_opt s (t#ts) = (s \<inter> t)#(intersection_list_opt (s - t) ts)"

lemma disjoint_subset: "disjoint A \<Longrightarrow> a \<in> A \<Longrightarrow> b \<subseteq> a \<Longrightarrow> disjoint ((A - {a}) \<union> {b})"
  apply(simp add: disjoint_def)
by blast

lemma disjoint_intersection: "disjoint A \<Longrightarrow> a \<in> A \<Longrightarrow> disjoint ({a \<inter> b} \<union> (A - {a}))"
  apply(simp add: disjoint_def)
by(blast)
 
lemma intersection_list_opt_lem0: "\<forall>t \<in> set(ts). u \<inter> t = {} \<Longrightarrow>
                                  intersection_list_opt s ts = intersection_list_opt (s - u) ts"
  apply(induction ts arbitrary: s u)
  apply(simp_all)
  by (metis Diff_Int_distrib2 Diff_empty Diff_eq Un_Diff_Int sup_bot.right_neutral)

lemma intersection_list_opt_lem1: "disjoint_list_rec (t # ts) \<Longrightarrow>
                                   intersection_list_opt s ts = intersection_list_opt (s - t) ts"
  apply(induction ts arbitrary: s t)
  apply(simp_all add: intersection_list_opt_lem0)
by (metis Diff_Int_distrib2 Diff_empty Un_empty inf_sup_distrib1)

lemma intList_equi: "disjoint_list_rec ts \<Longrightarrow> intersection_list s ts = intersection_list_opt s ts"
  apply(induction ts arbitrary: s)
  by(simp_all add: intersection_list_opt_lem1)

fun difference_list :: "'a set \<Rightarrow> 'a set list \<Rightarrow> 'a set list" where
  "difference_list _ [] = []" |
  "difference_list s (t#ts) = (t - s)#(difference_list s ts)"

fun difference_list_opt :: "'a set \<Rightarrow> 'a set list \<Rightarrow> 'a set list" where
  "difference_list_opt _ [] = []" |
  "difference_list_opt s (t#ts) = (t - s)#(difference_list_opt (s - t) ts)"

lemma difference_list_opt_lem0: "\<forall>t \<in> set(ts). u \<inter> t = {} \<Longrightarrow>
                                  difference_list_opt s ts = difference_list_opt (s - u) ts"
  apply(induction ts arbitrary: s u)
  apply(simp_all add: inter_dif_help_lemma)
  by (metis Diff_Int_distrib2 Diff_eq Un_Diff_Int sup_bot.right_neutral)

lemma difference_list_opt_lem1: "disjoint_list_rec (t # ts) \<Longrightarrow>
                                   difference_list_opt s ts = difference_list_opt (s - t) ts"
  apply(induction ts arbitrary: s t)
  apply(simp_all add: difference_list_opt_lem0)
by (metis Un_empty inf_sup_distrib1 inter_dif_help_lemma)


lemma difList_equi: "disjoint_list_rec ts \<Longrightarrow> difference_list s ts = difference_list_opt s ts"
  apply(induction ts arbitrary: s)
  apply(simp_all add: difference_list_opt_lem1)
done
 
fun partList0 :: "'a set \<Rightarrow> 'a set list \<Rightarrow> 'a set list" where
  "partList0 s [] = []" |
  "partList0 s (t#ts) = (s \<inter> t)#((t - s)#(partList0 s ts))"

lemma partList0_set_equi: "set(partList0 s ts) = ((op \<inter> s) ` (set ts)) \<union> ((\<lambda>x. x - s) ` (set ts))"
  apply(induction ts arbitrary: s)
  apply simp
  by(force)

lemma partList_sub_equi0: "set(partList0 s ts) =
                           set(difference_list s ts) \<union> set(intersection_list s ts)" 
  apply(induction ts arbitrary: s) by (simp_all)

fun partList1 :: "'a set \<Rightarrow> 'a set list \<Rightarrow> 'a set list" where
  "partList1 s [] = []" |
  "partList1 s (t#ts) = (s \<inter> t)#((t - s)#(partList1 (s - t) ts))"

lemma partList_sub_equi: "set(partList1 s ts) = 
                          set(difference_list_opt s ts) \<union> set(intersection_list_opt s ts)" 
  apply(induction ts arbitrary: s) by (simp_all)

lemma partList0_partList1_equi: "disjoint_list_rec ts \<Longrightarrow> set(partList0 s ts) = set(partList1 s ts)"
  by (simp add: partList_sub_equi partList_sub_equi0 intList_equi difList_equi)

fun partList2 :: "'a set \<Rightarrow> 'a set list \<Rightarrow> 'a set list" where
  "partList2 s [] = []" |
  "partList2 s (t#ts) = (if s \<inter> t = {} then  (t#(partList2 (s - t) ts))
                                       else (s \<inter> t)#((t - s)#(partList2 (s - t) ts)))"

lemma partList2_empty: "partList2 {} ts = ts"
  apply(induction ts) by (simp_all)
 
lemma partList1_partList3_equi: "set(partList1 s ts) - {{}} = set(partList2 s ts) - {{}}"
  apply(induction ts arbitrary: s)
  by(auto)

fun partList3 :: "'a set \<Rightarrow> 'a set list \<Rightarrow> 'a set list" where
  "partList3 s [] = []" |
  "partList3 s (t#ts) = (if s = {} then (t#ts) else
                          (if s \<inter> t = {} then  (t#(partList3 (s - t) ts))
                                         else 
                            (if t - s = {} then (t#(partList3 (s - t) ts))
                                           else (t \<inter> s)#((t - s)#(partList3 (s - t) ts)))))"

lemma partList2_partList3_equi: "set(partList2 s ts) - {{}} = set(partList3 s ts) - {{}}"
  apply(induction ts arbitrary: s)
  apply(simp)
  apply(simp_all add: partList2_empty)
by blast


(*TODO: add this to partList3*)
fun partList4 :: "'a set \<Rightarrow> 'a set list \<Rightarrow> 'a set list" where
  "partList4 s [] = []" |
  "partList4 s (t#ts) = (if s = {} then (t#ts) else
                          (if s \<inter> t = {} then (t#(partList4 s ts))
                                         else 
                            (if t - s = {} then (t#(partList4 (s - t) ts))
                                           else (t \<inter> s)#((t - s)#(partList4 (s - t) ts)))))"

lemma partList4: "set (partList3 s ts) = set (partList4 s ts)"
  apply(induction ts arbitrary: s)
   apply(simp)
  apply(simp)
  apply(intro conjI impI)
apply (simp add: Diff_triv)
done
(*TODO: use partList4 every time instead of partList3*)

lemma partList0_addSubsetSet_equi: "s \<subseteq> \<Union>(set ts) \<Longrightarrow> 
                                    addSubsetSet s (set ts) - {{}} = set(partList0 s ts) - {{}}"
  apply(simp_all add: addSubsetSet_def partList0_set_equi)
done

lemma partList3_addSubsetSet_equi: "disjoint_list_rec ts \<Longrightarrow> s \<subseteq> \<Union>(set ts) \<Longrightarrow>
                                    addSubsetSet s (set ts) - {{}} = set (partList3 s ts) - {{}}"
  apply(simp add: partList0_addSubsetSet_equi partList0_partList1_equi partList1_partList3_equi
               partList2_partList3_equi)
done

fun partitioning_nontail :: "'a set list \<Rightarrow> 'a set set \<Rightarrow> 'a set set" where
  "partitioning_nontail [] ts = ts" |
  "partitioning_nontail (s#ss) ts = addSubsetSet s (partitioning_nontail ss ts)"

lemma partitioningCom: "addSubsetSet a (partitioning ss ts) = partitioning ss (addSubsetSet a ts)"
  apply(induction ss arbitrary: a ts)
  apply(simp)
  apply(simp add: addSubsetSetCom)
done

lemma partitioning_nottail_equi: "partitioning_nontail ss ts = partitioning ss ts"
  apply(induction ss arbitrary: ts)
  apply(simp)
  apply(simp add: addSubsetSetCom partitioningCom)
done

fun partitioning1 :: "'a set list \<Rightarrow> 'a set list \<Rightarrow> 'a set list" where
  "partitioning1 [] ts = ts" |
  "partitioning1 (s#ss) ts = partList3 s (partitioning1 ss ts)"

lemma addSubsetSet_empty: "addSubsetSet s ts - {{}} = addSubsetSet s (ts - {{}}) - {{}}"
  apply(simp_all add: addSubsetSet_def)
by blast

lemma partList3_empty: "{} \<notin> set ts \<Longrightarrow> {} \<notin> set(partList3 s ts)"
  apply(induction ts arbitrary: s)
  apply(simp)
  by auto

lemma partitioning1_empty0: "{} \<notin> set ts \<Longrightarrow> {} \<notin> set(partitioning1 ss ts)"
  apply(induction ss arbitrary: ts)
  apply(simp)
  apply(simp add: partList3_empty)
done

lemma partitioning1_empty1: "{} \<notin> set ts \<Longrightarrow> 
                              set(partitioning1 ss ts) - {{}} = set(partitioning1 ss ts)"
  apply(simp add: partitioning1_empty0)
done

lemma partList3_subset: "a \<subseteq> \<Union>(set ts) \<Longrightarrow> a \<subseteq> \<Union>set (partList3 b ts)"
  apply(induction ts arbitrary: a b)
  apply(simp)
  apply(simp_all)
by fast

lemma "a \<noteq> {} \<Longrightarrow> disjoint_list_rec (a # ts) \<longleftrightarrow> disjoint_list_rec ts \<and> a \<inter> \<Union> (set ts) = {}"
  apply(induction ts arbitrary: a)
  apply(simp)
by force


lemma partList3_complete0: "s \<subseteq> \<Union> set ts \<Longrightarrow> \<Union> set ts = \<Union> set (partList3 s ts)"
proof(induction ts arbitrary: s)
  case Nil thus ?case by(simp)
  next
  case Cons thus ?case by (simp add: Diff_subset_conv Un_Diff_Int inf_sup_aci(7) sup.commute)
qed


lemma partList3_disjoint: "s \<subseteq> \<Union> set ts \<Longrightarrow> disjoint_list_rec ts \<Longrightarrow> 
                           disjoint_list_rec (partList3 s ts)"
  apply(induction ts arbitrary: s)
   apply(simp_all)
  apply(rule conjI)
   apply (metis Diff_subset_conv partList3_complete0)
  apply(safe)
      apply (metis Diff_subset_conv IntI UnionI partList3_complete0)
     apply (simp add: Diff_subset_conv)
    apply (metis Diff_subset_conv IntI UnionI partList3_complete0)
   apply (metis Diff_subset_conv IntI UnionI partList3_complete0)
  by (simp add: Diff_subset_conv)

lemma partitioning1_subset: "a \<subseteq> \<Union> (set ts) \<Longrightarrow> a \<subseteq> \<Union> set (partitioning1 ss ts)"
  apply(induction ss arbitrary: ts a)
  apply(simp)
  apply(simp add: partList3_subset)
done

lemma partitioning1_disjoint: "\<Union> (set ss) \<subseteq> \<Union> (set ts) \<Longrightarrow>
                               disjoint_list_rec ts \<Longrightarrow> disjoint_list_rec (partitioning1 ss ts)"
  proof(induction ss arbitrary: ts)
  qed(simp_all add: partList3_disjoint partitioning1_subset)

lemma partitioning_equi: "{} \<notin> set ts \<Longrightarrow> disjoint_list_rec ts \<Longrightarrow> \<Union> (set ss) \<subseteq> \<Union> (set ts) \<Longrightarrow>
         set(partitioning1 ss ts) = partitioning_nontail ss (set ts) - {{}}"
  apply(induction ss arbitrary: ts)
  apply(simp)
  apply(simp add: partList3_addSubsetSet_equi addSubsetSetCom partitioning1_empty0 
                  partitioning1_disjoint partitioning1_subset)
  apply(subst addSubsetSet_empty)
by (metis Diff_empty Diff_insert0 partList3_addSubsetSet_equi partList3_empty partitioning1_disjoint partitioning1_empty0 partitioning1_subset)

lemma disjoint_equi: "disjoint_list_rec ts \<Longrightarrow> disjoint (set ts)"
  apply(induction ts)
  apply(simp add: disjoint_def)
  apply(simp add: disjoint_def)
by blast

lemma ipPartitioning_helper_opt: "{} \<notin> set ts \<Longrightarrow> disjoint_list_rec ts \<Longrightarrow> \<Union> (set ss) \<subseteq> \<Union> (set ts) 
                                  \<Longrightarrow> ipPartition (set ss) (set (partitioning1 ss ts))"
  apply(simp add: partitioning_equi partitioning_nottail_equi ipPartitioning_helper disjoint_equi)
by (meson Diff_subset disjoint_equi ipPartition_def ipPartitioning_helper subsetCE)

lemma complete_helper: "{} \<notin> set ts \<Longrightarrow> disjoint_list_rec ts \<Longrightarrow> \<Union> (set ss) \<subseteq> \<Union> (set ts) 
                                  \<Longrightarrow> \<Union> (set ts) = \<Union> (set (partitioning1 ss ts))"
  apply(induction ss arbitrary: ts)
   apply(simp_all )
  by (metis partList3_complete0)

  
  

lemma "partitioning1  [{1::nat},{2},{}] [{1},{},{2},{3}] = [{1}, {}, {2}, {3}]" by eval


(*random corny stuff*)
lemma partitioning_foldr: "partitioning X B = foldr addSubsetSet X B"
  apply(induction X)
  apply(simp_all)
by (metis partitioningCom)

lemma "ipPartition (set X) (foldr addSubsetSet X {})"
  apply(subst partitioning_foldr[symmetric])
  using ipPartitioning by auto

term foldr
lemma "\<Union> (set X) = \<Union> (foldr addSubsetSet X {})"
  apply(subst partitioning_foldr[symmetric])
  by (simp add: coversallPartitioning)

lemma "partitioning1 X B = foldr partList3 X B"
  by(induction X)(simp_all)

lemma "ipPartition (set X) (set (partitioning1 X [UNIV]))"
apply(rule ipPartitioning_helper_opt)
apply(simp_all)
done

lemma "(\<Union>(set (partitioning1 X [UNIV]))) = UNIV"
apply(subgoal_tac "UNIV = \<Union> (set (partitioning1 X [UNIV]))")
 prefer 2
 apply(rule SetPartitioning.complete_helper[where ts="[UNIV]", simplified])
apply(simp)
done
  
end